#!/bin/sh
# Move the pins in versions.env to the heads of their branches:
#   LLVM_REF       ps2max32/llvm r5900-feature
#   MAXSDK_REF     ps2max32/maxsdk master   } only to a commit whose CI passed
#   LIBGL_REF      ps2max32/libgl master    } (gh api; needs GH_TOKEN)
#   PS2CLIENT_REF  rickgaiser/ps2client master
# Prints the pins it changed; exit 0 either way. picolibc, zlib, Alpine and
# ps2dev stay as they are: change those by hand.
set -e
cd "$(dirname "$0")/.."
. ./versions.env

head_of() { git ls-remote "$1" "refs/heads/$2" | cut -f1; }

# ci_passed <owner/repo> <commit>: every check run of the commit succeeded (or was skipped)
ci_passed() {
  gh api "repos/$1/commits/$2/check-runs" --jq \
    '.check_runs | length > 0 and all(.status == "completed" and (.conclusion == "success" or .conclusion == "skipped" or .conclusion == "neutral"))' \
    | grep -qx true
}

set_pin() {
  [ "$2" = "$(sed -n "s/^$1=//p" versions.env)" ] && return
  sed -i "s|^$1=.*|$1=$2|" versions.env
  echo "$1=$2"
}

set_pin LLVM_REF "$(head_of "$LLVM_REPO" r5900-feature)"
set_pin PS2CLIENT_REF "$(head_of "$PS2CLIENT_REPO" master)"
for lib in MAXSDK LIBGL; do
  eval repo=\$${lib}_REPO
  ref=$(head_of "$repo" master)
  if ci_passed "${repo#https://github.com/}" "$ref"; then
    set_pin ${lib}_REF "$ref"
  else
    echo "$lib: $ref has no passing CI, pin kept" >&2
  fi
done
