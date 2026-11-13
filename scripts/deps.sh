#!/bin/sh
# deps.sh [--check] [--dispatch] [<repo dir>...]
#
# Writes the ps2max.deps of ps2max repos from a ps2max tree: every KEY_REF=
# line the file has gets the commit (HEAD) of that dependency's checkout in the
# tree, the one the repo was built and tested with there. Run it before
# committing a change that needs newer dependencies, and commit ps2max.deps
# with it. Default: every repo under libs/ and apps/ that has a ps2max.deps.
#
#   LLVM_REF      toolchain/llvm/llvm-project   (ps2max32/llvm)
#   MAXSDK_REF    libs/maxsdk      LIBGL_REF   libs/libgl
#   MXLINK_REF    apps/mxlink      MXSHELL_REF apps/mxshell
#   PICOLIBC_REF  libs/picolibc    ZLIB_REF    libs/zlib     LWIP_REF libs/lwip
#
# It refuses commits that are not on GitHub (not in a branch or tag of the
# checkout's GitHub remote: push them first), warns about uncommitted changes
# (the CI does not have them), and checks that the CI image for each LLVM_REF
# exists (ghcr.io/ps2max32/ps2max:llvm-<12 digits>).
#   --check     change nothing; exit 1 when a file would change
#   --dispatch  start the images workflow of ps2max32/docker for an LLVM
#               without image (gh; about 2 hours)
#
# PS2MAX: the ps2max tree (default: two levels above this script).
set -eu

PS2MAX=${PS2MAX:-$(cd "$(dirname "$0")/../.." && pwd)}
check= dispatch=
while [ $# -gt 0 ]; do
  case $1 in
    --check) check=1 ;;
    --dispatch) dispatch=1 ;;
    -*) echo "usage: deps.sh [--check] [--dispatch] [<repo dir>...]" >&2; exit 64 ;;
    *) break ;;
  esac
  shift
done

dir_of() {
  case $1 in
    LLVM) echo toolchain/llvm/llvm-project ;;
    MAXSDK) echo libs/maxsdk ;; LIBGL) echo libs/libgl ;;
    MXLINK) echo apps/mxlink ;; MXSHELL) echo apps/mxshell ;;
    PICOLIBC) echo libs/picolibc ;; ZLIB) echo libs/zlib ;; LWIP) echo libs/lwip ;;
    *) return 1 ;;
  esac
}
github_of() {
  case $1 in
    LLVM) echo ps2max32/llvm ;; MAXSDK) echo ps2max32/maxsdk ;;
    LIBGL) echo ps2max32/libgl ;; MXLINK) echo ps2max32/mxlink ;;
    MXSHELL) echo ps2max32/mxshell ;; PICOLIBC) echo picolibc/picolibc ;;
    ZLIB) echo madler/zlib ;; LWIP) echo lwip-tcpip/lwip ;;
  esac
}

# on_github KEY DIR REF: REF is a branch head or tag of KEY's GitHub repo, or
# is in the history of a head (the heads that DIR has)
on_github() {
  refs=$(git ls-remote "https://github.com/$(github_of "$1")" 'refs/heads/*' 'refs/tags/*' | cut -f1) || return 1
  printf '%s\n' $refs | grep -qx "$3" && return 0
  for h in $(git ls-remote "https://github.com/$(github_of "$1")" 'refs/heads/*' | cut -f1); do
    git -C "$2" cat-file -e "$h^{commit}" 2>/dev/null && git -C "$2" merge-base --is-ancestor "$3" "$h" && return 0
  done
  # third-party repos (our checkout may not have their heads): ask GitHub
  case $1 in
    PICOLIBC|ZLIB|LWIP) gh api "repos/$(github_of "$1")/commits/$3" --silent 2>/dev/null ;;
    *) return 1 ;;
  esac
}

# resolve KEY: sets REF_<KEY> to its checkout's HEAD, checked once
resolve() {
  eval "[ -z \"\${REF_$1:-}\" ]" || return 0
  dir=$PS2MAX/$(dir_of "$1")
  ref=$(git -C "$dir" rev-parse HEAD)
  if ! on_github "$1" "$dir" "$ref"; then
    echo "deps: $1 $ref ($dir) is not on github.com/$(github_of "$1"): push it first" >&2
    ref=-
  elif [ "$1" != PICOLIBC ] && [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
    # picolibc: maxsdk's patch is applied in the checkout
    echo "deps: $1 ($dir) has uncommitted changes, which the CI does not have" >&2
  fi
  eval "REF_$1=\$ref"
}

if [ $# -eq 0 ]; then
  set -- $(cd "$PS2MAX" && ls -d libs/*/ps2max.deps apps/*/ps2max.deps 2>/dev/null | sed 's|/ps2max.deps$||')
fi

status=0 changed= llvm_refs=
for repo; do
  case $repo in /*) ;; *) [ -d "$repo" ] || repo=$PS2MAX/$repo ;; esac
  file=$repo/ps2max.deps
  [ -f "$file" ] || { echo "deps: no $file" >&2; status=1; continue; }
  name=$(basename "$(cd "$repo" && pwd)")
  for key in $(sed -n 's/^\([A-Z0-9]*\)_REF=.*/\1/p' "$file"); do
    dir_of "$key" > /dev/null || { echo "deps: $name: unknown ${key}_REF" >&2; status=1; continue; }
    resolve "$key"
    eval "ref=\$REF_$key"
    [ "$ref" != - ] || { status=1; continue; }
    [ "$key" = LLVM ] && llvm_refs="$llvm_refs $ref"
    old=$(sed -n "s/^${key}_REF=//p" "$file")
    [ "$old" = "$ref" ] && continue
    echo "$name: ${key}_REF $(echo "$old" | cut -c1-12) -> $(echo "$ref" | cut -c1-12)"
    changed=1
    [ -n "$check" ] || sed -i "s/^${key}_REF=.*/${key}_REF=$ref/" "$file"
  done
done

# the CI image of each LLVM
for ref in $(printf '%s\n' $llvm_refs | sort -u); do
  image=ghcr.io/ps2max32/ps2max:llvm-$(echo "$ref" | cut -c1-12)
  docker manifest inspect "$image" > /dev/null 2>&1 && continue
  if [ -n "$dispatch" ]; then
    gh workflow run images.yml -R ps2max32/docker -f llvm_ref="$ref"
    echo "deps: no $image yet: its build started (about 2 hours; gh run list -R ps2max32/docker)"
  else
    echo "deps: no $image yet: deps.sh --dispatch, or gh workflow run images.yml -R ps2max32/docker -f llvm_ref=$ref" >&2
  fi
done

[ -n "$check" ] && [ -n "$changed" ] && status=1
exit $status
