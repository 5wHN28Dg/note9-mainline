#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Build arm64 Image (with the milestone initramfs) and the crownlte DTB.
# Usage: scripts/build.sh <tree-dir> <out-dir>
# Env: CROSS_COMPILE (default aarch64-linux-gnu-)
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tree=$(cd "${1:?usage: $0 <tree> <out>}" && pwd)
mkdir -p "${2:?usage: $0 <tree> <out>}"
out=$(cd "$2" && pwd)
export ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
mk() { make -s -C "$tree" O="$out" -j"$(nproc)" "$@"; }

# Tiny init, built against the kernel's own nolibc (no external binaries).
mkdir -p "$out/initramfs/sysroot"
make -s -C "$tree/tools/include/nolibc" OUTPUT="$out/initramfs/sysroot/" \
	headers_standalone >/dev/null
"${CROSS_COMPILE}gcc" -Wall -Wextra -Werror -Os -s -static -nostdlib \
	-fno-asynchronous-unwind-tables -fno-ident -nostdinc \
	-I"$out/initramfs/sysroot/sysroot/include" -include nolibc.h \
	-o "$out/initramfs/init" "$repo/kernel/init.c" -lgcc
cat > "$out/initramfs/list" <<LIST
dir /dev 0755 0 0
nod /dev/console 0600 0 0 c 5 1
file /init $out/initramfs/init 0755 0 0
LIST

mk defconfig
echo "CONFIG_INITRAMFS_SOURCE=\"$out/initramfs/list\"" > "$out/initramfs.config"
(cd "$out" && "$tree/scripts/kconfig/merge_config.sh" -m -O "$out" .config \
	"$repo/kernel/crownlte.config" "$out/initramfs.config" >/dev/null)
mk olddefconfig

# Every fragment option must survive olddefconfig, or the build is not what we think.
fail=0
while IFS= read -r line; do
	case $line in CONFIG_*) ;; "# CONFIG_"*" is not set") ;; *) continue ;; esac
	grep -qxF "$line" "$out/.config" || { echo "fragment option lost: $line" >&2; fail=1; }
done < "$repo/kernel/crownlte.config"
[ "$fail" = 0 ]

mk Image
ls -l "$out/arch/arm64/boot/Image"
# Before the first patch lands there is no crownlte DTS yet. Once patches/
# has a series, the DTB is mandatory.
if ! compgen -G "$repo/patches/*.patch" >/dev/null; then
	echo "SKIP: patches/ is empty, no crownlte DTB to build yet"
	exit 0
fi
mk W=1 exynos/exynos9810-crownlte.dtb 2>&1 | tee "$out/dtb-build.log"
ls -l "$out/arch/arm64/boot/dts/exynos/exynos9810-crownlte.dtb"
