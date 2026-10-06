#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Fetch the pinned upstream kernel into $1 (if absent) and apply patches/.
# Usage: scripts/prepare-tree.sh <tree-dir>
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tree=${1:?usage: $0 <tree-dir>}
pin() { sed -n "s/^$1=//p" "$repo/kernel/PIN"; }
tag=$(pin tag) commit=$(pin commit) url=$(pin url) mirror=$(pin mirror)
[[ $commit =~ ^[0-9a-f]{40}$ ]] && [ -n "$tag" ] && [ -n "$url" ] ||
	{ echo "error: kernel/PIN incomplete" >&2; exit 1; }

if [ -e "$tree" ] && [ ! -d "$tree/.git" ]; then
	echo "error: $tree exists and is not a git tree" >&2
	exit 1
fi
if [ ! -d "$tree/.git" ]; then
	git clone -q --depth 1 --branch "$tag" "$url" "$tree" ||
		git clone -q --depth 1 --branch "$tag" "$mirror" "$tree"
fi
head=$(git -C "$tree" rev-parse "$tag^{commit}")
if [ "$head" != "$commit" ]; then
	echo "error: $tag resolves to $head, PIN says $commit" >&2
	exit 1
fi
git -C "$tree" -c advice.detachedHead=false checkout -q --force --detach "$commit"
# shellcheck source=scripts/series.sh
. "$repo/scripts/series.sh"
for p in "${series[@]}"; do
	git -C "$tree" -c user.name=ci -c user.email=ci@invalid am -q --keep-cr "$p"
done
applied=$(git -C "$tree" rev-list --count "$commit..HEAD")
[ "$applied" = "${#series[@]}" ] ||
	{ echo "error: ${#series[@]} patches but $applied commits on top of the pin" >&2; exit 1; }
echo "tree at $tag + $(git -C "$tree" rev-list --count "$commit..HEAD") patches"
