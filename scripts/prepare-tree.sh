#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Fetch the pinned upstream kernel into $1 (if absent) and apply patches/.
# Usage: scripts/prepare-tree.sh <tree-dir>
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tree=${1:?usage: $0 <tree-dir>}
# shellcheck disable=SC1091
. <(grep -E '^(tag|commit|url|mirror)=' "$repo/kernel/PIN")

if [ ! -d "$tree/.git" ]; then
	git clone -q --depth 1 --branch "$tag" "$url" "$tree" ||
		git clone -q --depth 1 --branch "$tag" "$mirror" "$tree"
fi
head=$(git -C "$tree" rev-parse "$tag^{commit}")
if [ "$head" != "$commit" ]; then
	echo "error: $tag resolves to $head, PIN says $commit" >&2
	exit 1
fi
git -C "$tree" checkout -q --detach "$commit"
shopt -s nullglob
patches=("$repo"/patches/[0-9][0-9][0-9][0-9]-*.patch)
for p in "${patches[@]}"; do
	case $p in */0000-cover-letter.patch) continue ;; esac
	git -C "$tree" -c user.name=ci -c user.email=ci@invalid am -q --keep-cr "$p"
done
echo "tree at $tag + $(git -C "$tree" rev-list --count "$commit..HEAD") patches"
