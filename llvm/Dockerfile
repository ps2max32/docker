# syntax=docker/dockerfile:1
# ghcr.io/ps2max32/llvm: the R5900/VU LLVM of ps2max (clang, lld, the tools
# maxsdk uses) in /opt/ps2max/llvm, plus the LLVM sources that builds on it
# compile themselves (compiler-rt builtins, libc++/libc++abi runtimes) in
# /opt/ps2max/llvm/src. Configured like ps2max's `configure.sh feature`.
#
#   docker build --build-arg LLVM_REF=<commit> -t ps2max32/llvm llvm/

ARG ALPINE=alpine:3.24

FROM ${ALPINE} AS build
RUN apk add --no-cache build-base cmake ninja python3 git linux-headers
ARG LLVM_REPO=https://github.com/ps2max32/llvm
ARG LLVM_REF
RUN test -n "$LLVM_REF" && git init -q /src && cd /src \
 && git fetch -q --depth 1 "$LLVM_REPO" "$LLVM_REF" && git checkout -q FETCH_HEAD
# PS2EE.cmake's toolchain tools plus llvm-mc and llvm-mca (used by maxsdk and
# the apps); they are set before the cache file, which then keeps them.
ARG TOOLS="llc;llvm-ar;llvm-as;llvm-cxxfilt;llvm-dis;llvm-mc;llvm-mca;llvm-nm;llvm-objcopy;llvm-objdump;llvm-ranlib;llvm-readelf;llvm-readobj;llvm-size;llvm-strings;llvm-strip;llvm-symbolizer;opt"
# JOBS: ninja parallelism (empty = all cores)
ARG JOBS=
RUN cmake -G Ninja -S /src/llvm -B /build \
      -DLLVM_TOOLCHAIN_TOOLS="$TOOLS" \
      -DLLVM_DISTRIBUTION_COMPONENTS="clang;lld;clang-resource-headers;builtins-mips64el-scei-ps2;$TOOLS" \
      -C /src/clang/cmake/caches/PS2EE.cmake \
      -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=VU \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/ps2max/llvm \
      -DLLVM_PARALLEL_LINK_JOBS=2 \
      -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
 && ninja -C /build ${JOBS:+-j$JOBS} install-distribution-stripped
# The sources builds on maxsdk compile: compiler-rt's builtins (maxsdk's
# libmxc) and the runtimes build of libc++/libc++abi (descent3), without tests.
RUN mkdir -p /opt/ps2max/llvm/src/compiler-rt/lib /opt/ps2max/llvm/src/llvm \
 && cd /src \
 && cp -a cmake runtimes libcxx libcxxabi libunwind /opt/ps2max/llvm/src/ \
 && cp -a compiler-rt/lib/builtins /opt/ps2max/llvm/src/compiler-rt/lib/ \
 && cp -a llvm/cmake llvm/utils /opt/ps2max/llvm/src/llvm/ \
 && rm -rf /opt/ps2max/llvm/src/libcxx/test /opt/ps2max/llvm/src/libcxxabi/test \
           /opt/ps2max/llvm/src/libunwind/test /opt/ps2max/llvm/src/llvm/utils/unittest \
 && git rev-parse HEAD > /opt/ps2max/llvm/REVISION

FROM ${ALPINE}
RUN apk add --no-cache libstdc++
COPY --from=build /opt/ps2max/llvm /opt/ps2max/llvm
ENV PS2MAX_LLVM_BIN=/opt/ps2max/llvm/bin \
    PS2MAX_LLVM_SRC=/opt/ps2max/llvm/src \
    PATH=/opt/ps2max/llvm/bin:$PATH
