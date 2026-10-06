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
# (Not "headers_standalone": that builds inside the source tree.)
sysroot=$out/initramfs/sysroot
mkdir -p "$sysroot"
make -s -C "$tree/tools/include/nolibc" OUTPUT="$sysroot/" headers
mk headers_install INSTALL_HDR_PATH="$sysroot/sysroot"
"${CROSS_COMPILE}gcc" -Wall -Wextra -Werror -Os -s -static -nostdlib \
	-fno-asynchronous-unwind-tables -fno-ident -nostdinc \
	-I"$sysroot/sysroot/include" -include nolibc.h \
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
	case $line in
	CONFIG_*)
		grep -qxF "$line" "$out/.config" ||
			{ echo "fragment option lost: $line" >&2; fail=1; } ;;
	"# CONFIG_"*" is not set")
		# Off, or absent because its dependencies are off: both fine.
		sym=${line#\# }; sym=${sym%% *}
		! grep -qE "^$sym=" "$out/.config" ||
			{ echo "fragment option not disabled: $sym" >&2; fail=1; }
		# A renamed symbol would make this guard a silent no-op.
		git -C "$tree" grep -qE "^(menu)?config ${sym#CONFIG_}\$" -- '*Kconfig*' ||
			{ echo "fragment symbol does not exist in this kernel: $sym" >&2; fail=1; } ;;
	esac
done < "$repo/kernel/crownlte.config"
[ "$fail" = 0 ]

mk Image
ls -l "$out/arch/arm64/boot/Image"
# Before the first patch lands there is no crownlte DTS yet. Once patches/
# has a series, the DTB is mandatory.
# shellcheck source=scripts/series.sh
. "$repo/scripts/series.sh"
if [ ${#patches[@]} = 0 ]; then
	echo "SKIP: patches/ is empty, no crownlte DTB to build yet"
	exit 0
fi
mk W=1 exynos/exynos9810-crownlte.dtb 2>&1 | tee "$out/dtb-build.log"
ls -l "$out/arch/arm64/boot/dts/exynos/exynos9810-crownlte.dtb"
