# ps2max32/docker

The CI of the ps2max repos (maxsdk, libgl, mxos, mxlink, mxshell and the games): the images it runs
in and the build every repo calls.

## How a repo's CI works

Each repo has a `ps2max.deps` with the commits of what it builds with:

```sh
LLVM_REF=b0afe6262a44b4902b9eb53b9f1c98fa02744fe0     # ps2max32/llvm: picks the image
MAXSDK_REF=983189d51dc1975b14e85384d08262c639accd0f   # ps2max32/maxsdk
LIBGL_REF=1eb53487a72e1884a36d847d6a3da120a4dbb2ec    # ps2max32/libgl
```

Its `.github/workflows/ps2.yml` calls `.github/workflows/build.yml` here (templates in `ci/`). That
build:

1. runs in `ghcr.io/ps2max32/ps2max:llvm-<LLVM_REF, 12 digits>`;
2. fetches the repos `ps2max.deps` names into `/opt/ps2max`, in ps2max's own layout, and builds maxsdk
   and picolibc there (`scripts/fetch-deps.sh`; kept in the Actions cache). A dependency's own
   `ps2max.deps` adds what it needs: maxsdk's names picolibc and lwIP;
3. builds the checkout (by default `make -j$(nproc) OUT=$PWD/out`): the Makefiles' defaults
   (`PS2MAX=/opt/ps2max`) find everything;
4. keeps the files `artifacts` names as an artifact, and on a tag `v*` makes a GitHub release with them.

So a repo always builds with the dependencies it was made with, whatever the other repos do.

| key | repo | in `/opt/ps2max` |
|---|---|---|
| `LLVM_REF` | ps2max32/llvm | `llvm` (the image) |
| `MAXSDK_REF` | ps2max32/maxsdk | `libs/maxsdk`, built in `build/libs/maxsdk` |
| `LIBGL_REF` | ps2max32/libgl | `libs/libgl` |
| `MXLINK_REF` | ps2max32/mxlink | `apps/mxlink` |
| `MXSHELL_REF` | ps2max32/mxshell | `apps/mxshell` |
| `PICOLIBC_REF` | picolibc | `libs/picolibc` (with maxsdk's patch), built in `build/libs/picolibc` |
| `ZLIB_REF` | zlib | `libs/zlib` |
| `LWIP_REF` | lwIP | `libs/lwip` |

maxsdk's CI passes `self: MAXSDK`: `libs/maxsdk` is then a link to the checkout, which builds itself.

## Moving a repo to newer dependencies

In a ps2max tree, after building and testing with the new versions:

```sh
docker/scripts/deps.sh              # every repo with a ps2max.deps under libs/ and apps/
docker/scripts/deps.sh apps/quake1  # or some
```

It sets each `KEY_REF` a `ps2max.deps` has to the commit (HEAD) of that dependency's checkout, refuses
commits that are not on GitHub yet, warns about uncommitted changes, and says when there is no image for
the LLVM yet; `--dispatch` starts that build (about 2 hours). Commit `ps2max.deps` with the change that
needs it. `--check` changes nothing and fails when a file would change.

## Images

| image | contents |
|---|---|
| `ghcr.io/ps2max32/llvm:<LLVM, 12>-<recipe>` | the R5900/VU LLVM: clang, lld, compiler-rt builtins for the EE and the IOP, llc, opt, llvm-mc, ... in `/opt/ps2max/llvm/bin`, and the LLVM sources builds compile themselves (compiler-rt builtins, libc++ runtimes) in `/opt/ps2max/llvm/src`. `<recipe>`: a hash of `llvm/Dockerfile` and Alpine |
| `ghcr.io/ps2max32/ps2max:llvm-<LLVM, 12>` | that LLVM, the build tools, ps2sdk's IOP headers and IRX modules from ps2dev in `/opt/ps2dev` (IOP code is built with LLVM), and `fetch-deps`. No ps2max libraries |

Both are Alpine, like ps2dev's images. `PS2MAX`, `PS2MAX_LLVM_BIN`, `PS2MAX_LLVM_SRC`, `PS2MAX_IRX`, ...
are set as `envsetup.sh` sets them.

`.github/workflows/images.yml` builds them for every `LLVM_REF` the ps2max32 repos name
(`scripts/llvm-refs.sh`): nightly the missing ones, on a push here all again (a changed recipe), and on
demand for one LLVM commit (`gh workflow run images.yml -R ps2max32/docker -f llvm_ref=<commit>`).
`versions.env` has the fixed inputs (Alpine, the ps2dev image).

## Building locally

```sh
set -a; . ./versions.env; set +a
docker build --build-arg ALPINE=$ALPINE --build-arg LLVM_REPO=$LLVM_REPO --build-arg LLVM_REF=<commit> \
  -t ps2max32/llvm:local llvm/
docker build --build-arg LLVM_IMAGE=ps2max32/llvm:local --build-arg PS2SDK_IMAGE=$PS2SDK_IMAGE \
  -t ps2max32/ps2max:local -f ps2max/Dockerfile .
# a repo's build, as the CI does it:
docker run --rm -v $PWD:/work ps2max32/ps2max:local sh -c 'fetch-deps ps2max.deps && make OUT=/work/out'
```
