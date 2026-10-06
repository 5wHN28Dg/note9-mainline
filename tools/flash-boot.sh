#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The ONLY script in this repo that writes to the phone. The owner runs it by
# hand; nothing else (no agent, no CI) ever runs it.
#
# It writes exactly one partition, and only BOOT or RECOVERY, via Heimdall in
# download mode. Before writing it checks that the image exists, is an Android
# boot image, and fits the partition, prints its SHA-256, and asks you to type
# the partition name to confirm.
#
# Usage:
#   tools/flash-boot.sh boot|recovery <image> [--reboot] [--dry-run]
#
#   --reboot   let the phone reboot after flashing (default: stay in download
#              mode, so you can use the key combo to go straight to recovery,
#              which TWRP needs on first install)
#   --dry-run  do all checks, print the Heimdall command, write nothing
#
# Partition sizes come from ~/note9-backups/partition-sizes.txt, written during
# the backup procedure (docs/PROCEDURES.md). Lines look like:
#   BOOT 46137344
#   RECOVERY 56623104
# Without that file the script refuses to run: no backup, no flash.

set -euo pipefail

SIZES=${NOTE9_SIZES:-$HOME/note9-backups/partition-sizes.txt}

die() { echo "flash-boot: $*" >&2; exit 1; }

[ $# -ge 2 ] || die "usage: $0 boot|recovery <image> [--reboot] [--dry-run]"
target=$1
image=$2
shift 2
reboot=0
dry=0
for a in "$@"; do
	case $a in
	--reboot) reboot=1 ;;
	--dry-run) dry=1 ;;
	*) die "unknown option: $a" ;;
	esac
done

# 1. Partition: an allow-list of exactly two names. Nothing else is accepted.
case $target in
boot | BOOT) part=BOOT ;;
recovery | RECOVERY) part=RECOVERY ;;
*) die "refusing: only 'boot' or 'recovery' may be written (got '$target')" ;;
esac

# 2. Image: exists, regular file, not empty, Android boot image magic.
[ -f "$image" ] || die "image not found or not a regular file: $image"
image=$(realpath -- "$image")	# absolute path: can never look like an option
size=$(stat -c %s "$image")
[ "$size" -gt 0 ] || die "image is empty: $image"
magic=$(head -c 8 "$image")
[ "$magic" = "ANDROID!" ] ||
	die "not an Android boot image (no ANDROID! header): $image
  (TWRP comes as .img or .img.tar; extract the .img first)"

# 3. Fits: compare with the real partition size recorded during backup.
[ -f "$SIZES" ] || die "missing $SIZES
  Do the backup first (docs/PROCEDURES.md). It records partition sizes."
max=$(awk -v p="$part" '$1 == p && $2 ~ /^[0-9]+$/ { print $2 }' "$SIZES")
[ -n "$max" ] || die "no size for $part in $SIZES"
[ "$size" -le "$max" ] ||
	die "image is $size bytes, $part partition is only $max bytes"

sum=$(sha256sum "$image" | cut -d' ' -f1)

cmd=(heimdall flash "--$part" "$image")
[ "$reboot" = 1 ] || cmd+=(--no-reboot)

cat <<EOF

  Partition : $part   (only this partition is written)
  Image     : $image
  Size      : $size bytes (partition: $max bytes)
  SHA-256   : $sum
  Command   : ${cmd[*]}

EOF

if [ "$dry" = 1 ]; then
	echo "dry run: nothing written"
	exit 0
fi

command -v heimdall >/dev/null || die "heimdall not found (see docs/PROCEDURES.md)"
echo "Phone must be in download mode and connected by USB."
heimdall detect >/dev/null 2>&1 || die "no phone in download mode detected"

read -r -p "Type $part to write it, anything else aborts: " answer
[ "$answer" = "$part" ] || die "aborted, nothing written"

"${cmd[@]}"
echo
echo "Done: wrote $part ($sum)."
if [ "$reboot" = 0 ]; then
	echo "Phone is still in download mode. To go straight to recovery:"
	echo "hold Volume Down + Power until the screen goes black, then at once"
	echo "switch to Volume Up + Bixby + Power and hold until recovery appears."
fi
