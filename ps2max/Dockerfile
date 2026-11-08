# syntax=docker/dockerfile:1
# ghcr.io/ps2max32/ps2max: everything to build ps2max programs, on the llvm
# image. /opt/ps2max has ps2max's own layout (PS2MAX=/opt/ps2max), so the
# Makefiles' defaults find everything:
#   libs/maxsdk, libs/libgl, libs/picolibc, libs/zlib, libs/lwip   sources at pinned commits
#   build/libs/maxsdk, build/libs/picolibc/install       built
#   tools/ps2client/bin/ps2client
# and the IOP side of ps2dev (ps2sdk's IOP headers and prebuilt IRX modules;
# IOP code is built with LLVM) in /opt/ps2dev. A repo's CI builds its checkout against this, e.g.
#   make -C apps/quake1 OUT=$PWD/out
#
#   docker build --build-arg LLVM_IMAGE=... --build-arg PS2SDK_IMAGE=... \
#     --build-arg MAXSDK_REF=... (see versions.env) -t ps2max32/ps2max ps2max/

ARG LLVM_IMAGE=ghcr.io/ps2max32/llvm:latest
ARG PS2SDK_IMAGE=ps2dev/ps2sdk:latest

FROM ${PS2SDK_IMAGE} AS ps2dev

FROM ${LLVM_IMAGE}
RUN apk add --no-cache bash build-base cmake coreutils git make meson ninja python3
# The IOP side of ps2dev: the only parts of ps2dev ps2max uses. ps2sdk's IOP
# headers and its prebuilt IRX modules
COPY --from=ps2dev /usr/local/ps2dev/ps2sdk/iop/irx /opt/ps2dev/ps2sdk/iop/irx
COPY --from=ps2dev /usr/local/ps2dev/ps2sdk/iop/include /opt/ps2dev/ps2sdk/iop/include
COPY --from=ps2dev /usr/local/ps2dev/ps2sdk/common/include /opt/ps2dev/ps2sdk/common/include
ENV PS2MAX=/opt/ps2max \
    PS2MAX_PS2DEV=/opt/ps2dev \
    PS2MAX_IOP_SDK=/opt/ps2dev/ps2sdk \
    PS2MAX_IRX=/opt/ps2dev/ps2sdk/iop/irx \
    PS2CLIENT=/opt/ps2max/tools/ps2client/bin/ps2client \
    PATH=/opt/ps2max/tools/ps2client/bin:$PATH

ARG MAXSDK_REPO=https://github.com/ps2max32/maxsdk
ARG MAXSDK_REF
ARG LIBGL_REPO=https://github.com/ps2max32/libgl
ARG LIBGL_REF
ARG PICOLIBC_REPO=https://github.com/picolibc/picolibc
ARG PICOLIBC_REF
ARG ZLIB_REPO=https://github.com/madler/zlib
ARG ZLIB_REF
ARG LWIP_REPO=https://github.com/lwip-tcpip/lwip
ARG LWIP_REF
ARG PS2CLIENT_REPO=https://github.com/rickgaiser/ps2client
ARG PS2CLIENT_REF
# fetch <repo> <commit> <dir>: that commit only, without history
RUN printf '%s\n' '#!/bin/sh' 'set -e' \
      'test -n "$2" || { echo "fetch: no ref for $1" >&2; exit 1; }' \
      'git init -q "$3" && cd "$3"' \
      'git fetch -q --depth 1 "$1" "$2" && git checkout -q FETCH_HEAD' \
      'git rev-parse HEAD > .revision && rm -rf .git' > /usr/local/bin/fetch \
 && chmod +x /usr/local/bin/fetch \
 && fetch "$MAXSDK_REPO" "$MAXSDK_REF" /opt/ps2max/libs/maxsdk \
 && fetch "$LIBGL_REPO" "$LIBGL_REF" /opt/ps2max/libs/libgl \
 && fetch "$PICOLIBC_REPO" "$PICOLIBC_REF" /opt/ps2max/libs/picolibc \
 && fetch "$ZLIB_REPO" "$ZLIB_REF" /opt/ps2max/libs/zlib \
 && fetch "$LWIP_REPO" "$LWIP_REF" /opt/ps2max/libs/lwip \
 && fetch "$PS2CLIENT_REPO" "$PS2CLIENT_REF" /opt/ps2max/tools/ps2client \
 && cd /opt/ps2max/libs/picolibc && patch -p1 < ../maxsdk/ee/libc/picolibc-r5900.patch
RUN make -C /opt/ps2max/libs/maxsdk picolibc \
 && make -C /opt/ps2max/libs/maxsdk -j"$(nproc)" lib libc \
 && make -C /opt/ps2max/tools/ps2client \
 && rm -rf /opt/ps2max/build/libs/picolibc/build-meson
WORKDIR /work
