#!/usr/bin/env bash
set -euo pipefail

readonly targets="arm armv5 arm6 armv7 aarch64 x86 amd64 mips mipsel mips64 mips64el"

usage() {
  cat <<EOF
Usage:
  docker run --rm -e MUSL_TARGET=<target> IMAGE <command> [args...]

Targets:
  ${targets}

Convenience commands:
  cc, c++, gcc, g++, ar, as, ld, nm, objcopy, objdump, ranlib,
  readelf, and strip use the selected cross-toolchain.
EOF
}

case "${1:-}" in
  targets)
    printf '%s\n' ${targets}
    exit 0
    ;;
  help|--help|-h)
    usage
    exit 0
    ;;
esac

target=${MUSL_TARGET:-}
case " ${targets} " in
  *" ${target} "*) ;;
  *)
    if [[ -z ${target} ]]; then
      echo "error: MUSL_TARGET is required" >&2
    else
      echo "error: unsupported MUSL_TARGET: ${target}" >&2
    fi
    usage >&2
    exit 2
    ;;
esac

sdk_dir="/opt/musl-cross/${target}"
# The Buildroot environment file sets CC/CXX and the complete binutils paths.
# shellcheck disable=SC1091
source "${sdk_dir}/environment-setup"

if (( $# == 0 )); then
  set -- bash
fi

command_name=$1
shift
case "${command_name}" in
  cc|gcc) command_name=${CC} ;;
  c++|g++) command_name=${CXX} ;;
  ar) command_name=${AR} ;;
  as) command_name=${AS} ;;
  ld) command_name=${LD} ;;
  nm) command_name=${NM} ;;
  objcopy) command_name=${OBJCOPY} ;;
  objdump) command_name=${OBJDUMP} ;;
  ranlib) command_name=${RANLIB} ;;
  readelf) command_name=${READELF} ;;
  strip) command_name=${STRIP} ;;
esac

exec "${command_name}" "$@"
