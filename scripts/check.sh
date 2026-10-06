#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# All patch/DT checks. Fails on the first broken check class, after running all.
# Usage: scripts/check.sh <tree-dir prepared by prepare-tree.sh> <out-dir from build.sh>
# Needs dtschema + yamllint on PATH (see README).
set -uo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tree=$(cd "${1:?usage: $0 <tree> <out>}" && pwd)
out=$(cd "${2:?usage: $0 <tree> <out>}" && pwd)
export ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
# shellcheck disable=SC1091
. <(grep -E '^commit=' "$repo/kernel/PIN")
shopt -s nullglob
patches=("$repo"/patches/*.patch)
status=0
if [ ${#patches[@]} = 0 ]; then
	echo "SKIP: patches/ is empty, nothing to check yet"
	exit 0
fi
fail() { echo "FAIL: $*" >&2; status=1; }

# Files our series touches (relative to the tree root).
mapfile -t touched < <(git -C "$tree" diff --name-only "$commit"..HEAD)
echo "series touches ${#touched[@]} files: ${touched[*]}"

echo "== 1. no Signed-off-by in any patch"
if grep -n '^Signed-off-by:' "${patches[@]}" /dev/null; then
	fail "patches must not carry Signed-off-by (owner adds their own)"
fi

echo "== 2. checkpatch --strict --no-signoff"
# FILE_PATH_CHANGES ("does MAINTAINERS need updating?") is ignored: adding a
# MAINTAINERS entry would name a maintainer, which is the owner's decision.
# The existing Exynos DTS entry already covers arch/arm64/boot/dts/exynos/.
for p in "${patches[@]}"; do
	case $p in */0000-cover-letter.patch) continue ;; esac
	(cd "$tree" && scripts/checkpatch.pl --strict --no-signoff \
		--ignore FILE_PATH_CHANGES --show-types -q "$p") ||
		fail "checkpatch: $(basename "$p")"
done

echo "== 3. W=1 CHECK_DTBS=y exynos/exynos9810-crownlte.dtb"
log=$out/dtbs-check.log
# Force a rebuild: an up-to-date DTB would skip validation silently.
rm -f "$out/arch/arm64/boot/dts/exynos/exynos9810-crownlte.dtb"
make -s -C "$tree" O="$out" W=1 CHECK_DTBS=y exynos/exynos9810-crownlte.dtb >"$log" 2>&1 ||
	fail "dtbs_check build exited non-zero"
cat "$log"
# Any line naming the crownlte DTB/DTS or another touched file fails.
# (Schema findings do not contain the word "warning", so match file names.)
pattern='exynos9810-crownlte'
for f in "${touched[@]}"; do pattern+="|$(basename "$f" | sed 's/[.]/[.]/g')"; done
if grep -E "$pattern" "$log"; then
	fail "dtbs_check findings on files we touch"
fi
# dtc warnings from the W=1 build in build.sh, same rule.
if [ -f "$out/dtb-build.log" ] && grep -E "$pattern" "$out/dtb-build.log"; then
	fail "dtc (W=1) warnings on files we touch"
fi

echo "== 4. dt_binding_check (only if bindings changed)"
mapfile -t bindings < <(printf '%s\n' "${touched[@]}" | grep '^Documentation/devicetree/bindings/.*\.yaml$')
if [ ${#bindings[@]} -gt 0 ]; then
	blog=$out/binding-check.log
	files=$(IFS=:; echo "${bindings[*]}")
	make -s -C "$tree" O="$out/bindings" dt_binding_check \
		DT_SCHEMA_FILES="$files" >"$blog" 2>&1 || fail "dt_binding_check exited non-zero"
	cat "$blog"
	if grep -E -i "warning|error|$(IFS='|'; echo "${bindings[*]##*/}")" "$blog"; then
		fail "dt_binding_check findings"
	fi
else
	echo "no binding changes, skipped"
fi

[ $status = 0 ] && echo "all checks passed"
exit $status
