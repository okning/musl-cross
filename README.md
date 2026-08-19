# musl-cross

Reproducible Linux cross-toolchain SDKs built with Buildroot and musl. Each
target is available with compilers that run natively on either **aarch64 Linux**
or **x86_64 Linux** and generate binaries for these targets:

| Release name | Target | Baseline CPU / ABI |
| --- | --- | --- |
| `arm` | Generic 32-bit ARM | ARM926EJ-S, ARMv5TE, EABI, soft-float |
| `armv5` | 32-bit ARM | ARM926EJ-S, ARMv5TE, EABI, soft-float |
| `arm6` | 32-bit ARM | ARM1136J-S, ARMv6, EABI, soft-float |
| `armv7` | 32-bit ARM | Cortex-A9, EABIhf, VFPv3-D16; no hardware divide requirement |
| `aarch64` | 64-bit ARM | Cortex-A53, ARMv8-A, LP64 |
| `x86` | 32-bit x86 | i486; no i586/i686, MMX, or SSE requirement |
| `amd64` | 64-bit x86 | x86-64-v1; no AVX requirement |
| `mips` | 32-bit big-endian MIPS | MIPS32, o32, soft-float |
| `mipsel` | 32-bit little-endian MIPS | MIPS32, o32, soft-float |
| `mips64` | 64-bit big-endian MIPS | MIPS64, n64, soft-float |
| `mips64el` | 64-bit little-endian MIPS | MIPS64, n64, soft-float |

All target libc/sysroot builds except AArch64 use Linux 2.6.32.71 UAPI headers.
AArch64, which was introduced after Linux 2.6.32, uses Linux 3.10.108 headers.
This prevents each toolchain from assuming APIs newer than its stated kernel
floor. It does not guarantee that every third-party program will run on that
kernel: applications must avoid newer syscalls or provide fallbacks, and should
be tested on the actual target.

## Using a release

```sh
tar -xzf musl-armv5-x86_64-linux.tar.gz
cd musl-armv5-x86_64-linux
./relocate-sdk.sh
. ./environment-setup
${CC} hello.c -o hello
```

Choose the archive matching the host machine (`aarch64` or `x86_64`). Both C
and C++ are enabled. The archive also contains `manifest.txt`,
`sha256sums.txt`, and statically linked `smoke-test` and `smoke-test-cxx`
target binaries.

## Using the container image

Each tagged release also publishes `ghcr.io/okning/musl-cross:<version>` and
updates `ghcr.io/okning/musl-cross:latest`. The image supports both
`linux/amd64` and `linux/arm64`; each platform contains all eleven toolchains
built natively for that Linux host architecture.

Select a toolchain with `MUSL_TARGET`, mount the source tree at `/work`, and use
the convenience `cc` or `c++` command:

```sh
docker run --rm \
  -e MUSL_TARGET=armv7 \
  -v "$PWD:/work" \
  ghcr.io/okning/musl-cross:latest \
  cc -static -Os hello.c -o hello-armv7
```

For build systems that consume compiler environment variables, run a shell in
the selected environment. `CC`, `CXX`, binutils variables, `PATH`, and sysroot
variables are loaded from the corresponding Buildroot SDK:

```sh
docker run --rm \
  -e MUSL_TARGET=mipsel \
  -v "$PWD:/work" \
  ghcr.io/okning/musl-cross:latest \
  bash -c 'make CC="$CC" CXX="$CXX"'
```

Run the image with `targets` to print the accepted `MUSL_TARGET` values. Docker
on macOS can run this Linux image, but the included compilers remain
Linux-hosted executables rather than native macOS binaries.

## Building

The project pins Buildroot in [`scripts/versions.env`](scripts/versions.env).
On an aarch64 or x86_64 Linux machine with the Buildroot prerequisites
installed:

```sh
./scripts/build-toolchain.sh armv5
```

Use `arm`, `arm6`, `armv7`, `aarch64`, `x86`, `amd64`, `mips`, `mipsel`,
`mips64`, or `mips64el` for the other targets. Output archives are written to
`dist/`. GitHub Actions builds all eleven target
configurations for both host architectures on native runners. Pushing a tag
such as `v0.1.0` creates a GitHub Release and attaches every SDK plus a
top-level checksum file.

Every build runs an architecture-specific compatibility gate against the
compiler defaults, ELF headers and attributes, and the disassembly of a static
musl smoke binary. The smoke binary deliberately exercises `calloc` and
integer division so the check covers allocator and compiler-runtime paths, not
only a trivial `puts` call. The enforced baselines are ARMv5TE/soft-float,
ARMv6/soft-float, ARMv7-A/VFPv3-D16/hard-float without hardware divide,
ARMv8-A/LP64, i486, x86-64-v1, MIPS32 Release 1/o32/soft-float, and MIPS64
Release 1/n64/soft-float in both byte orders. Builds fail if they expose a
newer default or emit representative newer-ISA instructions.

In particular, the ARMv7 compiler defaults to `-mcpu=cortex-a9`,
`-mfpu=vfpv3-d16`, and `-mfloat-abi=hard`. This avoids the hardware divide and
VFPv4 instructions enabled by the previous Cortex-A7/VFPv4 configuration
while retaining EABIhf compatibility. The 32-bit x86 target is similarly
lowered from i686 to i486 so it does not silently require conditional moves or
SSE.

## Compatibility boundary

Linux 2.6.32 is the configured target kernel ABI floor for all targets except
AArch64, whose floor is Linux 3.10.108. These target floors are not minimum
kernel versions for the **host** that runs the compiler. In particular, this
project does not claim that AArch64-hosted SDK executables run on Linux 2.6.32.
