#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Collect the facts the port needs from the phone. READ-ONLY on the phone.
# Run it yourself with the phone in TWRP and connected by USB.
#
# Output goes to ~/note9-logs/<date-time>/ (outside the repo). These files
# contain serial numbers and similar; never commit them. Send them to the
# agent by leaving them there.

set -euo pipefail
die() { echo "collect-info: $*" >&2; exit 1; }

[ "$(adb get-state 2>/dev/null)" = recovery ] ||
	die "phone not in recovery (TWRP) over adb; check 'adb devices'"

dest=$HOME/note9-logs/$(date +%Y-%m-%d-%H%M)
mkdir -p "$dest"
cd "$dest"

# What S-Boot really hands to a kernel: the device tree (with RAM layout and
# command line), the RAM map, and the command line itself.
adb exec-out 'cat /sys/firmware/fdt' > fdt.dtb
adb exec-out 'cat /proc/iomem' > iomem.txt
adb exec-out 'cat /proc/cmdline' > cmdline.txt
adb exec-out 'cat /proc/cpuinfo' > cpuinfo.txt
adb exec-out 'getprop' > getprop.txt
adb exec-out 'dmesg' > dmesg.txt 2>/dev/null || true
adb exec-out 'cat /proc/last_kmsg' > last_kmsg.txt 2>/dev/null || true
adb exec-out 'ls -l /sys/fs/pstore' > pstore-list.txt 2>/dev/null || true

ls -l
echo "Saved to $dest"
