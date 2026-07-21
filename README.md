# musl-cross

Reproducible Linux cross-toolchain SDKs built with Buildroot and musl. Each
target is available with compilers that run natively on either **aarch64 Linux**
or **x86_64 Linux** and generate binaries for these targets:

| Release name | Target | Baseline CPU / ABI |
| --- | --- | --- |
| `armv5` | 32-bit ARM | ARM926T, EABI, soft-float |
| `armv7` | 32-bit ARM | Cortex-A9, EABIhf, VFPv3-D16; no hardware divide requirement |
| `x86` | 32-bit x86 | i486; no i586/i686, MMX, or SSE requirement |
| `amd64` | 64-bit x86 | x86-64-v1; no AVX requirement |
| `mips` | 32-bit big-endian MIPS | MIPS32, o32, soft-float |
| `mipsel` | 32-bit little-endian MIPS | MIPS32, o32, soft-float |

All target libc/sysroot builds use Linux 2.6.32.71 UAPI headers. This prevents
the toolchain from assuming APIs newer than Linux 2.6.32. It does not guarantee
that every third-party program will run on that kernel: applications must avoid
newer syscalls or provide fallbacks, and should be tested on the actual target.

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
`sha256sums.txt`, and a statically linked `smoke-test` target binary.

## Building

The project pins Buildroot in [`scripts/versions.env`](scripts/versions.env).
On an aarch64 or x86_64 Linux machine with the Buildroot prerequisites
installed:

```sh
./scripts/build-toolchain.sh armv5
```

Use `armv7`, `x86`, `amd64`, `mips`, or `mipsel` for the other targets. Output
archives are written to `dist/`. GitHub Actions builds all six target
configurations for both host architectures on native runners. Pushing a tag
such as `v0.1.0` creates a GitHub Release and attaches every SDK plus a
top-level checksum file.

Every build runs an architecture-specific compatibility gate against the
compiler defaults, ELF headers and attributes, and the disassembly of a static
musl smoke binary. The smoke binary deliberately exercises `calloc` and
integer division so the check covers allocator and compiler-runtime paths, not
only a trivial `puts` call. The enforced baselines are ARMv5TE/soft-float,
ARMv7-A/VFPv3-D16/hard-float without hardware divide, i486, x86-64-v1, and
MIPS32 Release 1/o32/soft-float in both byte orders. Builds fail if they expose
a newer default or emit representative newer-ISA instructions.

In particular, the ARMv7 compiler defaults to `-mcpu=cortex-a9`,
`-mfpu=vfpv3-d16`, and `-mfloat-abi=hard`. This avoids the hardware divide and
VFPv4 instructions enabled by the previous Cortex-A7/VFPv4 configuration
while retaining EABIhf compatibility. The 32-bit x86 target is similarly
lowered from i686 to i486 so it does not silently require conditional moves or
SSE.

## Compatibility boundary

Linux 2.6.32 is the configured target kernel ABI floor, not the minimum kernel
for the **host** that runs the compiler. In particular, AArch64 did not exist in
Linux 2.6.32, so this project deliberately does not claim that the SDK
executables themselves run on a 2.6.32 host kernel.
