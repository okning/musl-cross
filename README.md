# musl-cross

Reproducible Linux cross-toolchain SDKs built with Buildroot and musl. Each
target is available with compilers that run natively on either **aarch64 Linux**
or **x86_64 Linux** and generate binaries for these targets:

| Release name | Target | Baseline CPU / ABI |
| --- | --- | --- |
| `armv5` | 32-bit ARM | ARM926T, EABI, soft-float |
| `armv7` | 32-bit ARM | Cortex-A7, EABIhf |
| `x86` | 32-bit x86 | i686 |
| `amd64` | 64-bit x86 | generic x86-64 |
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

## Compatibility boundary

Linux 2.6.32 is the configured target kernel ABI floor, not the minimum kernel
for the **host** that runs the compiler. In particular, AArch64 did not exist in
Linux 2.6.32, so this project deliberately does not claim that the SDK
executables themselves run on a 2.6.32 host kernel.
