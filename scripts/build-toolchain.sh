#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${project_root}/scripts/versions.env"

target=${1:-}
case "${target}" in
  armv5|armv7|x86|amd64|mips|mipsel) ;;
  *)
    echo "usage: $0 {armv5|armv7|x86|amd64|mips|mipsel}" >&2
    exit 2
    ;;
esac

if [[ $(uname -s) != Linux || $(uname -m) != aarch64 ]]; then
  echo "error: SDK host binaries must be built natively on aarch64 Linux" >&2
  exit 1
fi

download_dir=${DOWNLOAD_DIR:-"${project_root}/.cache/downloads"}
buildroot_dir="${project_root}/buildroot-${BUILDROOT_VERSION}"
output_dir="${project_root}/output/${target}"
dist_dir="${project_root}/dist"
archive="buildroot-${BUILDROOT_VERSION}.tar.xz"
archive_path="${download_dir}/${archive}"

mkdir -p "${download_dir}" "${dist_dir}"
if [[ ! -f "${archive_path}" ]]; then
  curl --fail --location --retry 3 \
    "https://buildroot.org/downloads/${archive}" -o "${archive_path}"
fi
echo "${BUILDROOT_SHA256}  ${archive_path}" | sha256sum --check --status

if [[ ! -d "${buildroot_dir}" ]]; then
  tar -xf "${archive_path}" -C "${project_root}"
fi

make -C "${buildroot_dir}" O="${output_dir}" \
  BR2_DEFCONFIG="${project_root}/configs/${target}_defconfig" defconfig
make -C "${buildroot_dir}" O="${output_dir}" -j"$(nproc)" toolchain

cross_compile=$(sed -n 's/^BR2_TOOLCHAIN_EXTERNAL_PREFIX="\(.*\)"/\1/p' "${output_dir}/.config")
if [[ -z "${cross_compile}" ]]; then
  cross_compile=$(make -s -C "${buildroot_dir}" O="${output_dir}" printvars \
    VARS=GNU_TARGET_NAME QUOTED_VARS=YES | sed -n "s/^GNU_TARGET_NAME='\(.*\)'/\1/p")
fi
test -n "${cross_compile}"

"${output_dir}/host/bin/${cross_compile}-gcc" -static -Os \
  "${project_root}/tests/smoke.c" -o "${output_dir}/smoke-test"
"${output_dir}/host/bin/${cross_compile}-readelf" -h "${output_dir}/smoke-test"

sdk_prefix="muslforge-${target}-aarch64-linux"
make -C "${buildroot_dir}" O="${output_dir}" \
  BR2_SDK_PREFIX="${sdk_prefix}" sdk

staging=$(mktemp -d)
trap 'rm -rf "${staging}"' EXIT
tar -xzf "${output_dir}/images/${sdk_prefix}.tar.gz" -C "${staging}"
cp "${output_dir}/smoke-test" "${staging}/${sdk_prefix}/"
{
  echo "project=muslforge"
  echo "target=${target}"
  echo "host=aarch64-linux"
  echo "buildroot=${BUILDROOT_VERSION}"
  echo "libc=musl"
  echo "kernel_headers=2.6.32.71"
  echo "target_tuple=${cross_compile}"
} > "${staging}/${sdk_prefix}/manifest.txt"
(
  cd "${staging}/${sdk_prefix}"
  find . -type f ! -name sha256sums.txt -print0 | sort -z | xargs -0 sha256sum > sha256sums.txt
)
tar -czf "${dist_dir}/${sdk_prefix}.tar.gz" -C "${staging}" "${sdk_prefix}"
(
  cd "${dist_dir}"
  sha256sum "${sdk_prefix}.tar.gz" > "${sdk_prefix}.tar.gz.sha256"
)
