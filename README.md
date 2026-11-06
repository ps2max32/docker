# ps2max32/docker

Docker images for building ps2max programs (maxsdk, libgl, mxlink and the apps) in CI.

| image | contents |
|---|---|
| `ghcr.io/ps2max32/llvm` | the R5900/VU LLVM (ps2max32/llvm, branch r5900-feature): clang, lld, llc, opt, llvm-mc, ... in `/opt/ps2max/llvm/bin`, and the LLVM sources builds compile themselves (compiler-rt builtins, libc++ runtimes) in `/opt/ps2max/llvm/src` |
| `ghcr.io/ps2max32/ps2max` | the llvm image plus maxsdk (built), picolibc (built, with maxsdk's patch), libgl, zlib and ps2client in `/opt/ps2max`, in ps2max's own layout; the IOP gcc, ps2sdk's IOP build files (headers, link script, iopfixup) and IRX modules from ps2dev in `/opt/ps2dev` |

Both are Alpine, like ps2dev's images (the IOP gcc is copied from `ps2dev/ps2sdk`).
`PS2MAX`, `PS2MAX_LLVM_BIN`, `PS2MAX_LLVM_SRC`, `PS2MAX_IRX`, ... are set as `envsetup.sh` sets them,
so the Makefiles' defaults work:

```sh
docker run --rm -v $PWD:/work ghcr.io/ps2max32/ps2max make OUT=/work/out   # in an app's checkout
```

## Versions

`versions.env` pins every input. `.github/workflows/images.yml`:

- nightly and on demand, `scripts/bump.sh` moves the llvm, maxsdk, libgl and ps2client pins to their
  branch heads (maxsdk and libgl only to a commit whose CI passed) and commits `versions.env`;
- builds `llvm:<LLVM_REF>` if there is none yet (about 2 hours), then `ps2max:<commit of this repo>`;
- builds every repo's default branch with that image, and tags it `ps2max:latest` only if all of them build.

picolibc, zlib, Alpine and the ps2dev image are changed by hand in `versions.env`.

## The repos' CI

`ci/` has the `.github/workflows/ps2.yml` of each repo: `maxsdk.yml`, `libgl.yml`, `mxlink.yml` (the PS2's
loader), and `app.yml` for quake1, quake2, quake3, descent3 and hexen2 (ELF as an artifact; a release on a `v*` tag).

## Building locally

```sh
set -a; . ./versions.env; set +a
docker build --build-arg ALPINE=$ALPINE --build-arg LLVM_REPO=$LLVM_REPO --build-arg LLVM_REF=$LLVM_REF \
  -t ps2max32/llvm:local llvm/
docker build --build-arg LLVM_IMAGE=ps2max32/llvm:local --build-arg PS2SDK_IMAGE=$PS2SDK_IMAGE \
  $(for v in MAXSDK LIBGL PICOLIBC ZLIB PS2CLIENT; do eval echo --build-arg ${v}_REPO=\$${v}_REPO --build-arg ${v}_REF=\$${v}_REF; done) \
  -t ps2max32/ps2max:local ps2max/
```
