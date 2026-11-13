# syntax=docker/dockerfile:1
# ghcr.io/ps2max32/ps2max:llvm-<LLVM commit, 12 digits>: the toolchain to
# build ps2max programs, on the llvm image of that commit. It has no ps2max
# libraries: a build fetches the ones it needs at the commits its ps2max.deps
# names (scripts/fetch-deps.sh, which the CI runs) into /opt/ps2max, in
# ps2max's own layout (PS2MAX=/opt/ps2max), so the Makefiles' defaults find them.
#
# Here: the LLVM in /opt/ps2max/llvm, the build tools, and the IOP side of
# ps2dev (ps2sdk's IOP headers and prebuilt IRX modules; IOP code is built
# with LLVM) in /opt/ps2dev.
#
#   docker build --build-arg LLVM_IMAGE=ghcr.io/ps2max32/llvm:<commit> \
#     --build-arg PS2SDK_IMAGE=... (see versions.env) -t ps2max32/ps2max -f ps2max/Dockerfile .

ARG LLVM_IMAGE=ghcr.io/ps2max32/llvm:latest
ARG PS2SDK_IMAGE=ps2dev/ps2sdk:latest

FROM ${PS2SDK_IMAGE} AS ps2dev

FROM ${LLVM_IMAGE}
# tar and zstd: actions/cache in the CI
RUN apk add --no-cache bash build-base cmake coreutils git make meson ninja patch python3 tar zstd
# The IOP side of ps2dev: the only parts of ps2dev ps2max uses. ps2sdk's IOP
# headers and its prebuilt IRX modules
COPY --from=ps2dev /usr/local/ps2dev/ps2sdk/iop/irx /opt/ps2dev/ps2sdk/iop/irx
COPY --from=ps2dev /usr/local/ps2dev/ps2sdk/iop/include /opt/ps2dev/ps2sdk/iop/include
COPY --from=ps2dev /usr/local/ps2dev/ps2sdk/common/include /opt/ps2dev/ps2sdk/common/include
# LWIP: maxsdk's iop/tcpip/mxnet finds lwIP relative to its own directory,
# which is not libs/maxsdk when that is a link to the checkout (fetch-deps SELF)
ENV PS2MAX=/opt/ps2max \
    PS2MAX_PS2DEV=/opt/ps2dev \
    PS2MAX_IOP_SDK=/opt/ps2dev/ps2sdk \
    PS2MAX_IRX=/opt/ps2dev/ps2sdk/iop/irx \
    LWIP=/opt/ps2max/libs/lwip
# for local use (the CI runs the script of the workflow's own commit)
COPY scripts/fetch-deps.sh /usr/local/bin/fetch-deps
RUN git config --system --add safe.directory '*'
WORKDIR /work
