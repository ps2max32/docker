#!/bin/sh
# fetch-deps.sh <ps2max.deps> [PS2MAX]
#
# Puts the ps2max repos a build depends on into PS2MAX (default: $PS2MAX, else
# /opt/ps2max), in ps2max's own layout, at the commits <ps2max.deps> names,
# and builds maxsdk (and picolibc) there, so the Makefiles' defaults find them.
# Used by the CI (.github/workflows/build.yml) in the ps2max image; also works
# in a local `docker run` of that image.
#
# ps2max.deps has one KEY_REF=<commit> per line (# comments allowed):
#   LLVM_REF      the LLVM (ps2max32/llvm): not fetched, the image has it; checked
#   MAXSDK_REF    ps2max32/maxsdk   -> libs/maxsdk (built: picolibc, lib, libc)
#   LIBGL_REF     ps2max32/libgl    -> libs/libgl
#   MXLINK_REF    ps2max32/mxlink   -> apps/mxlink
#   MXSHELL_REF   ps2max32/mxshell  -> apps/mxshell
#   PICOLIBC_REF  picolibc          -> libs/picolibc (with maxsdk's patch)
#   ZLIB_REF      zlib              -> libs/zlib
#   LWIP_REF      lwIP              -> libs/lwip
# A fetched dependency's own ps2max.deps adds the keys the file does not set
# (an app names MAXSDK_REF; maxsdk's file names its PICOLIBC_REF and LWIP_REF).
#
# SELF=<KEY> (e.g. SELF=MAXSDK) with SELF_DIR=<checkout>: the repo being built
# is that dependency; its directory in PS2MAX becomes a link to the checkout
# and is not built here (the repo's own build does that).
#
# What is already there at the right commit (a cache) is kept: each directory
# has a .revision, the builds a stamp.
set -eu

deps=$1
root=${2:-${PS2MAX:-/opt/ps2max}}
SELF=${SELF:-}
SELF_DIR=${SELF_DIR:-$PWD}
KEYS="MAXSDK LIBGL MXLINK MXSHELL PICOLIBC ZLIB LWIP"

url_of() {
  case $1 in
    MAXSDK) echo https://github.com/ps2max32/maxsdk ;;
    LIBGL) echo https://github.com/ps2max32/libgl ;;
    MXLINK) echo https://github.com/ps2max32/mxlink ;;
    MXSHELL) echo https://github.com/ps2max32/mxshell ;;
    PICOLIBC) echo https://github.com/picolibc/picolibc ;;
    ZLIB) echo https://github.com/madler/zlib ;;
    LWIP) echo https://github.com/lwip-tcpip/lwip ;;
  esac
}
dir_of() {
  case $1 in
    MAXSDK) echo libs/maxsdk ;; LIBGL) echo libs/libgl ;;
    MXLINK) echo apps/mxlink ;; MXSHELL) echo apps/mxshell ;;
    PICOLIBC) echo libs/picolibc ;; ZLIB) echo libs/zlib ;; LWIP) echo libs/lwip ;;
  esac
}

# get KEY: its ref so far (empty if none); set KEY REF: only if not set yet
get() { eval "echo \"\${DEP_$1:-}\""; }
set_ref() { [ -n "$(get "$1")" ] || eval "DEP_$1=\$2"; }
# read_deps FILE: the KEY_REF lines of FILE that are not set yet
read_deps() {
  [ -f "$1" ] || return 0
  for kv in $(sed -n 's/^[[:space:]]*\([A-Z0-9]*\)_REF=\([0-9a-f]*\).*/\1=\2/p' "$1"); do
    set_ref "${kv%%=*}" "${kv#*=}"
  done
}

read_deps "$deps"

# The image's LLVM must be the one the build names.
llvm=$(get LLVM)
have=$(cat "$root/llvm/REVISION" 2>/dev/null || true)
if [ -n "$llvm" ] && [ -n "$have" ] && [ "$llvm" != "$have" ]; then
  echo "fetch-deps: $deps names LLVM $llvm, this image has $have" >&2
  exit 1
fi

# fetch KEY: its repo at its ref into its directory (or the link for SELF)
fetch() {
  dir=$root/$(dir_of "$1")
  if [ "$1" = "$SELF" ]; then
    [ "$(readlink "$dir" 2>/dev/null)" = "$SELF_DIR" ] && return
    rm -rf "$dir" && mkdir -p "$(dirname "$dir")" && ln -s "$SELF_DIR" "$dir"
    echo "fetch-deps: $1 = $SELF_DIR (this checkout)"
    return
  fi
  ref=$(get "$1")
  if [ "$(cat "$dir/.revision" 2>/dev/null)" = "$ref" ]; then
    echo "fetch-deps: $1 $ref (cached)"
    return
  fi
  echo "fetch-deps: $1 $ref"
  rm -rf "$dir" && mkdir -p "$dir"
  (cd "$dir" && git init -q && git fetch -q --depth 1 "$(url_of "$1")" "$ref" \
     && git -c advice.detachedHead=false checkout -q FETCH_HEAD && rm -rf .git)
  echo "$ref" > "$dir/.revision"
}

# Fetch until no dependency adds another: a fetched repo's ps2max.deps may
# name more. maxsdk first: picolibc needs its patch.
done_keys=
while :; do
  more=
  for k in $KEYS; do
    [ -n "$(get "$k")" ] || [ "$k" = "$SELF" ] || continue
    case " $done_keys " in *" $k "*) continue ;; esac
    fetch "$k"
    done_keys="$done_keys $k"
    read_deps "$root/$(dir_of "$k")/ps2max.deps"
    more=1
  done
  [ -n "$more" ] || break
done

maxsdk=$root/libs/maxsdk
if [ ! -f "$maxsdk/Makefile" ]; then
  echo "fetch-deps: no maxsdk (MAXSDK_REF), nothing to build"
  exit 0
fi

# picolibc: maxsdk's patch on it, built with maxsdk's cross file. The stamp
# names the picolibc commit, the patch and the LLVM.
patch=$maxsdk/ee/libc/picolibc-r5900.patch
if [ -n "$(get PICOLIBC)" ]; then
  stamp="$(get PICOLIBC) $(sha256sum < "$patch" | cut -c1-16) $have"
  inst=$root/build/libs/picolibc
  if [ "$(cat "$inst/.stamp" 2>/dev/null)" != "$stamp" ]; then
    echo "fetch-deps: picolibc build"
    # a cached picolibc may carry an older patch: fetch it again
    if [ -f "$root/libs/picolibc/.patched" ]; then
      rm -f "$root/libs/picolibc/.revision"
      fetch PICOLIBC
    fi
    (cd "$root/libs/picolibc" && patch -s -p1 < "$patch" && touch .patched)
    rm -rf "$inst"
    make -C "$maxsdk" PS2MAX="$root" picolibc > "$root/picolibc-build.log" 2>&1 \
      || { tail -50 "$root/picolibc-build.log"; exit 1; }
    rm -rf "$inst/build-meson"
    echo "$stamp" > "$inst/.stamp"
  fi
fi

# maxsdk itself (not when it is the repo being built: its own build does it)
if [ "$SELF" != MAXSDK ]; then
  stamp="$(get MAXSDK) $(cat "$root/build/libs/picolibc/.stamp" 2>/dev/null) $have"
  out=$root/build/libs/maxsdk
  if [ "$(cat "$out/.stamp" 2>/dev/null)" != "$stamp" ]; then
    echo "fetch-deps: maxsdk build"
    rm -rf "$out"
    make -C "$maxsdk" PS2MAX="$root" -j"$(nproc)" lib libc
    echo "$stamp" > "$out/.stamp"
  fi
fi
