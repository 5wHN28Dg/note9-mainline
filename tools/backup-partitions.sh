#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Back up the Note 9's partitions to this PC. READ-ONLY on the phone: it
# only lists, measures, checksums and reads block devices through adb.
# It never pushes, writes, mounts or formats anything on the phone.
#
# Run it yourself with the phone booted into TWRP ("Keep Read Only") and
# connected by USB. See docs/PROCEDURES.md.
#
# Usage: tools/backup-partitions.sh [<pit-file>]
#   <pit-file>: the PIT saved with "heimdall download-pit" (copied into the
#               backup and checksummed).
#
# Output: ~/note9-backups/<date-time>/ with one <NAME>.img per partition,
# SHA256SUMS, partition-sizes.txt and by-name.txt. Also updates
# ~/note9-backups/partition-sizes.txt (BOOT/RECOVERY), which
# tools/flash-boot.sh uses.

set -euo pipefail

# Too big, user data, or rebuilt from firmware anyway (CLAUDE.md).
SKIP_RE='^(system|vendor|odm|userdata|cache|hidden)$'

die() { echo "backup: $*" >&2; exit 1; }
sh() { adb shell "$@" | tr -d '\r'; }

pit=${1:-}
[ -z "$pit" ] || [ -f "$pit" ] || die "PIT file not found: $pit"

command -v adb >/dev/null || die "adb not found"
[ "$(adb get-state 2>/dev/null)" = recovery ] ||
	die "phone not in recovery (TWRP) over adb; check 'adb devices'"

byname=$(sh 'ls -d /dev/block/platform/*/by-name' | head -n 1)
[[ $byname =~ ^/dev/block/platform/[A-Za-z0-9._-]+/by-name$ ]] ||
	die "can't find the by-name directory (got '$byname')"

base=$HOME/note9-backups
dest=$base/$(date +%Y-%m-%d-%H%M%S)
[ ! -e "$dest" ] || die "$dest already exists"
mkdir -p "$dest"
cd "$dest"

sh "ls -l $byname" > by-name.txt
list=$(sh "ls $byname") || die "listing $byname failed"
mapfile -t names <<<"$list"
[ ${#names[@]} -gt 0 ] || die "no partitions listed"
# Check every name before reading anything.
for n in "${names[@]}"; do
	[[ $n =~ ^[A-Za-z0-9_]+$ ]] || die "unexpected partition name '$n'"
done
# The IMEI lives here: a backup without it is not a backup.
for need in EFS BOOT RECOVERY; do
	printf '%s\n' "${names[@]}" | grep -qx "$need" || die "$need not in the by-name list"
done

: > partition-sizes.txt
for n in "${names[@]}"; do
	if [[ ${n,,} =~ $SKIP_RE ]]; then
		echo "skip  $n"
		continue
	fi
	dev=$byname/$n
	size=$(sh "blockdev --getsize64 $dev")
	[[ $size =~ ^[0-9]+$ ]] || die "can't read size of $n ('$size')"
	echo "read  $n ($size bytes)"
	adb exec-out "cat $dev" > "$n.img"
	got=$(stat -c %s "$n.img")
	[ "$got" = "$size" ] || die "$n: got $got bytes, expected $size"
	phone_sum=$(sh "sha256sum $dev" | cut -d' ' -f1)
	pc_sum=$(sha256sum "$n.img" | cut -d' ' -f1)
	[ "$phone_sum" = "$pc_sum" ] || die "$n: checksum differs between phone and PC"
	echo "$n $size" >> partition-sizes.txt
done

if [ -n "$pit" ]; then
	cp -- "$pit" note9.pit
fi
sha256sum -- *.img ${pit:+note9.pit} > SHA256SUMS
chmod -R a-w "$dest"

# Measured sizes for tools/flash-boot.sh.
grep -E '^(BOOT|RECOVERY) ' partition-sizes.txt > "$base/partition-sizes.txt.new"
[ "$(wc -l < "$base/partition-sizes.txt.new")" = 2 ] ||
	die "BOOT/RECOVERY not both found; see $dest/by-name.txt"
mv "$base/partition-sizes.txt.new" "$base/partition-sizes.txt"

echo
echo "Backup done: $dest"
echo "Now copy that whole folder to a second drive, then check the copy with:"
echo "  (cd <copy> && sha256sum -c SHA256SUMS)"
