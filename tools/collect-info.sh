#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Collect the facts the port needs from the phone. READ-ONLY on the phone.
# Run it yourself with the phone in TWRP and connected by USB.
#
# Output goes to ~/Projects/note9-logs/<date-time>/ (outside the repo). These files
# contain serial numbers and similar; never commit them. Send them to the
# agent by leaving them there.

set -euo pipefail
die() { echo "collect-info: $*" >&2; exit 1; }

[ "$(adb get-state 2>/dev/null)" = recovery ] ||
	die "phone not in recovery (TWRP) over adb; check 'adb devices'"

dest=$HOME/Projects/note9-logs/$(date +%Y-%m-%d-%H%M%S)
[ ! -e "$dest" ] || die "$dest already exists"
mkdir -p "$dest"
cd "$dest"

# What S-Boot really hands to a kernel: the device tree (with RAM layout and
# command line), the RAM map, and the command line itself.
# Each read is optional: one failure must not stop the rest.
get() {
	adb exec-out "$1" > "$2" 2>/dev/null || echo "warning: '$1' failed" >&2
}
get 'cat /sys/firmware/fdt' fdt.dtb
get 'cat /proc/iomem' iomem.txt
get 'cat /proc/cmdline' cmdline.txt
get 'cat /proc/cpuinfo' cpuinfo.txt
get 'getprop' getprop.txt
get 'dmesg' dmesg.txt
get 'cat /proc/last_kmsg' last_kmsg.txt
get 'ls -l /sys/fs/pstore' pstore-list.txt

ls -l
echo "Saved to $dest"
