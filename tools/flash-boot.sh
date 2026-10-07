#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The ONLY script in this repo that writes to the phone. The owner runs it by
# hand; nothing else (no agent, no CI) ever runs it.
#
# It writes exactly one partition, and only BOOT or RECOVERY, via Heimdall in
# download mode. It copies the image to a private temp dir first, then checks
# that copy (Android boot image header, fits the partition, optional expected
# SHA-256), prints its SHA-256, asks you to type the partition name, and
# flashes that same copy.
#
# Usage:
#   tools/flash-boot.sh boot|recovery <image> [options]
#
#   --expect-sha256 <sum>  refuse unless the image has this SHA-256
#                          (use it when restoring a backup)
#   --reboot               let the phone reboot after flashing (default: stay
#                          in download mode, so you can go straight to
#                          recovery with the key combo; TWRP needs that)
#   --dry-run              do all checks, print the command, write nothing
#
# Partition sizes: ~/note9-backups/partition-sizes.txt if it exists (measured
# on your phone during the backup, docs/PROCEDURES.md), otherwise the sizes
# LineageOS declares for this phone (tools/partition-sizes.lineageos.txt).
# Either way each size must be between 8 MiB and 128 MiB.
#
# Getting into download mode: phone off, USB cable plugged into the PC, hold
# Bixby + Volume Down + Power, then press Volume Up at the warning screen.
# Check the screen shows "KG STATE: Normal" before flashing.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
measured=$HOME/note9-backups/partition-sizes.txt
fallback=$here/partition-sizes.lineageos.txt
min_size=$((8 * 1024 * 1024))
max_size=$((128 * 1024 * 1024))

die() { echo "flash-boot: $*" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: $0 boot|recovery <image> [--expect-sha256 SUM] [--reboot] [--dry-run]"
target=$1
src=$2
shift 2
reboot=0
dry=0
expect=
while [ $# -gt 0 ]; do
	case $1 in
	--reboot) reboot=1 ;;
	--dry-run) dry=1 ;;
	--expect-sha256)
		[ $# -ge 2 ] || die "--expect-sha256 needs a value"
		expect=${2,,}
		[[ $expect =~ ^[0-9a-f]{64}$ ]] || die "not a SHA-256: $2"
		shift ;;
	*) die "unknown option: $1" ;;
	esac
	shift
done

# 1. Partition: an allow-list of exactly two names. Nothing else is accepted.
case $target in
boot | BOOT) part=BOOT ;;
recovery | RECOVERY) part=RECOVERY ;;
*) die "refusing: only 'boot' or 'recovery' may be written (got '$target')" ;;
esac

# 2. Work on a private copy, so the file can't change between check and flash.
[ -f "$src" ] || die "image not found or not a regular file: $src"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"
image=$tmp/$part.img		# absolute path: can never look like an option
cp -- "$src" "$image"

# 3. The copy: not empty, Android boot image magic.
size=$(stat -c %s "$image")
[ "$size" -gt 0 ] || die "image is empty: $src"
magic=$(head -c 8 "$image")
[ "$magic" = "ANDROID!" ] ||
	die "not an Android boot image (no ANDROID! header): $src
  TWRP comes as .img or .img.tar (extract the .img); stock boot from Samsung
  firmware is boot.img.lz4 inside the AP tar (decompress with: lz4 -d)."

# 4. Fits the partition.
if [ -f "$measured" ]; then
	sizes=$measured
	src_note="measured on your phone"
else
	sizes=$fallback
	src_note="declared by LineageOS, not measured on your phone yet"
fi
max=$(awk -v p="$part" '$1 == p { n++; v = $2 } END { if (n == 1) print v }' "$sizes")
[[ $max =~ ^[0-9]{1,12}$ ]] || die "need exactly one numeric $part line in $sizes"
[ "$max" -ge "$min_size" ] && [ "$max" -le "$max_size" ] ||
	die "$part size $max in $sizes is not 8-128 MiB; wrong units? (must be bytes)"
[ "$size" -le "$max" ] ||
	die "image is $size bytes, $part partition is only $max bytes"

# 5. Checksum of the exact bytes that will be written.
sum=$(sha256sum "$image" | cut -d' ' -f1)
if [ -n "$expect" ] && [ "$sum" != "$expect" ]; then
	die "SHA-256 mismatch: image is $sum, expected $expect"
fi

cmd=(heimdall flash "--$part" "$image")
[ "$reboot" = 1 ] || cmd+=(--no-reboot)

cat <<EOF

  Partition : $part   (only this partition is written)
  Image     : $src
  Size      : $size bytes (partition: $max bytes, $src_note)
  SHA-256   : $sum${expect:+  (matches expected)}
  Command   : $(printf '%q ' "${cmd[@]}")

EOF

if [ "$dry" = 1 ]; then
	echo "dry run: nothing written"
	exit 0
fi

[ -t 0 ] || die "confirmation must be typed at a terminal"
command -v heimdall >/dev/null || die "heimdall not found (see docs/PROCEDURES.md)"
echo "Phone must be in download mode and connected by USB."
heimdall detect >/dev/null 2>&1 || die "no phone in download mode detected"

read -r -p "Type $part to write it, anything else aborts: " answer
[ "$answer" = "$part" ] || die "aborted, nothing written"

"${cmd[@]}"
echo
echo "Done: wrote $part ($sum)."
if [ "$reboot" = 0 ]; then
	cat <<EOF
The phone is still in download mode. To go straight to recovery: hold
Volume Down + Power until the screen goes black, then at once switch to
Bixby + Volume Up + Power and hold until recovery appears.
EOF
fi
