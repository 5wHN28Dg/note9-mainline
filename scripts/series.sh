# SPDX-License-Identifier: GPL-2.0
# shellcheck shell=bash disable=SC2154
# Sourced by the other scripts: the one definition of "the patch series".
# Sets: patches (all patch files incl. cover letter), series (without it).
# Anything in patches/ that isn't NNNN-*.patch (or README.md) is an error,
# so a misnamed series can't make CI skip silently.
shopt -s nullglob
patches=("$repo"/patches/[0-9][0-9][0-9][0-9]-*.patch)
series=()
for _p in "${patches[@]}"; do
	case $_p in */0000-cover-letter.patch) ;; *) series+=("$_p") ;; esac
done
for _f in "$repo"/patches/* "$repo"/patches/.[!.]*; do
	case $_f in
	"$repo"/patches/[0-9][0-9][0-9][0-9]-*.patch | "$repo"/patches/README.md) ;;
	*) echo "FAIL: unexpected file in patches/: ${_f##*/}" >&2; exit 1 ;;
	esac
done
unset _p _f
