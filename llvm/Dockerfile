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
# the apps); they are set before the cache file, which then keeps them. Its
# LLVM_DISTRIBUTION_COMPONENTS (clang, lld, the EE's and the IOP's compiler-rt
# builtins, these tools) is what gets installed.
ARG TOOLS="llc;llvm-ar;llvm-as;llvm-cxxfilt;llvm-dis;llvm-mc;llvm-mca;llvm-nm;llvm-objcopy;llvm-objdump;llvm-ranlib;llvm-readelf;llvm-readobj;llvm-size;llvm-strings;llvm-strip;llvm-symbolizer;opt"
# JOBS: ninja parallelism (empty = all cores)
# The tablegen'd headers (the *_gen targets) are made first: clangCodeGen
# does not depend on analysis_gen (TargetLibraryInfo.inc), so a parallel
# build can compile it before that header exists.
ARG JOBS=
RUN cmake -G Ninja -S /src/llvm -B /build \
      -DLLVM_TOOLCHAIN_TOOLS="$TOOLS" \
      -C /src/clang/cmake/caches/PS2EE.cmake \
      -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=VU \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/ps2max/llvm \
      -DLLVM_PARALLEL_LINK_JOBS=2 \
      -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
 && ninja -C /build ${JOBS:+-j$JOBS} $(ninja -C /build -t targets all | sed -n 's/^\([A-Za-z0-9_]*_gen\): phony.*/\1/p') \
 && ninja -C /build ${JOBS:+-j$JOBS} install-distribution-stripped
# clang's HLSL headers (hlsl.h): maxsdk's HLSL programs (mk/maxsdk.mk) are
# compiled by clang for SPIR-V; PS2EE.cmake does not list them
RUN ninja -C /build install-hlsl-resource-headers
# The sources builds on maxsdk compile: compiler-rt's builtins (maxsdk's
# libmxc) and the runtimes build of libc++/libc++abi (descent3; libc++
# includes LLVM libc's shared headers), without tests.
RUN mkdir -p /opt/ps2max/llvm/src/compiler-rt/lib /opt/ps2max/llvm/src/llvm \
 && cd /src \
 && cp -a cmake runtimes libc libcxx libcxxabi libunwind /opt/ps2max/llvm/src/ \
 && cp -a compiler-rt/lib/builtins /opt/ps2max/llvm/src/compiler-rt/lib/ \
 && cp -a llvm/cmake llvm/utils /opt/ps2max/llvm/src/llvm/ \
 && rm -rf /opt/ps2max/llvm/src/libcxx/test /opt/ps2max/llvm/src/libcxxabi/test \
           /opt/ps2max/llvm/src/libunwind/test /opt/ps2max/llvm/src/llvm/utils/unittest \
           /opt/ps2max/llvm/src/libc/test /opt/ps2max/llvm/src/libc/benchmarks \
           /opt/ps2max/llvm/src/libc/fuzzing /opt/ps2max/llvm/src/libc/docs \
 && git rev-parse HEAD > /opt/ps2max/llvm/REVISION

FROM ${ALPINE}
RUN apk add --no-cache libstdc++
COPY --from=build /opt/ps2max/llvm /opt/ps2max/llvm
ENV PS2MAX_LLVM_BIN=/opt/ps2max/llvm/bin \
    PS2MAX_LLVM_SRC=/opt/ps2max/llvm/src \
    PATH=/opt/ps2max/llvm/bin:$PATH
