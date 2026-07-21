#!/usr/bin/env bash
set -euo pipefail

target=${1:-}
tool_prefix=${2:-}
binary=${3:-}
case "${target}" in
  armv5|armv7|x86|amd64|mips|mipsel) ;;
  *)
    echo "usage: $0 {armv5|armv7|x86|amd64|mips|mipsel} TOOL_PREFIX BINARY" >&2
    exit 2
    ;;
esac
if [[ -z ${tool_prefix} || -z ${binary} ]]; then
  echo "usage: $0 {armv5|armv7|x86|amd64|mips|mipsel} TOOL_PREFIX BINARY" >&2
  exit 2
fi

compiler="${tool_prefix}-gcc"
readelf="${tool_prefix}-readelf"
objdump="${tool_prefix}-objdump"
for tool in "${compiler}" "${readelf}" "${objdump}"; do
  if [[ ! -x ${tool} ]]; then
    echo "error: required tool is not executable: ${tool}" >&2
    exit 1
  fi
done
if [[ ! -f ${binary} ]]; then
  echo "error: smoke binary not found: ${binary}" >&2
  exit 1
fi

target_options=$("${compiler}" -Q --help=target -c -x c /dev/null -o /dev/null)
elf_header=$("${readelf}" -h "${binary}")
attributes=$("${readelf}" -A "${binary}")
disassembly=$("${objdump}" -d "${binary}")

require_text() {
  local description=$1
  local pattern=$2
  local content=$3

  if ! grep -Eq "${pattern}" <<< "${content}"; then
    echo "error: ${target} compatibility check failed: expected ${description}" >&2
    exit 1
  fi
}

reject_instruction() {
  local description=$1
  local pattern=$2

  if grep -Eiq "${pattern}" <<< "${disassembly}"; then
    echo "error: ${target} smoke binary uses unsupported ${description}" >&2
    grep -Eim 5 "${pattern}" <<< "${disassembly}" >&2
    exit 1
  fi
}

reject_instruction_except() {
  local description=$1
  local pattern=$2
  local allowed_symbols=$3
  local line symbol=''
  local -a violations=()

  while IFS= read -r line; do
    if [[ ${line} =~ ^[[:xdigit:]]+[[:space:]]+\<([^\>]*)\>: ]]; then
      symbol=${BASH_REMATCH[1]}
    elif [[ ${line} =~ ${pattern} && ! ${symbol} =~ ${allowed_symbols} ]]; then
      violations+=("${symbol}: ${line}")
    fi
  done <<< "${disassembly}"

  if (( ${#violations[@]} > 0 )); then
    echo "error: ${target} smoke binary uses unsupported ${description}" >&2
    printf '  %s\n' "${violations[@]:0:5}" >&2
    exit 1
  fi
}

case "${target}" in
  armv5)
    require_text '-mcpu=arm926ej-s' '[[:space:]]-mcpu=[[:space:]]+arm926ej-s([[:space:]]|$)' "${target_options}"
    require_text '-mfloat-abi=soft' '[[:space:]]-mfloat-abi=[[:space:]]+soft([[:space:]]|$)' "${target_options}"
    require_text '32-bit ARM ELF' 'Class:[[:space:]]+ELF32' "${elf_header}"
    require_text 'ARM EABI soft-float flags' 'Flags:.*soft-float ABI' "${elf_header}"
    require_text 'ARMv5TE attributes' 'Tag_CPU_arch:[[:space:]]+v5TE' "${attributes}"
    # musl contains runtime-selected ARMv6/ARMv7 atomic helpers even in its
    # ARMv5 build. They are reached only after kernel/CPU capability checks;
    # newer instructions anywhere else remain a compatibility failure.
    reject_instruction_except 'ARMv6+ or VFP instructions' \
      '[[:space:]](ldrex[a-z]*|strex[a-z]*|dmb|dsb|isb|movw|movt|sdiv|udiv|v[a-z0-9.]+)[[:space:]]' \
      '^__a_(barrier_v6|barrier_v7|cas_v6|cas_v7|gettp_cp15)$'
    ;;
  armv7)
    require_text '-mcpu=cortex-a9' '[[:space:]]-mcpu=[[:space:]]+cortex-a9([[:space:]]|$)' "${target_options}"
    require_text '-mfpu=vfpv3-d16' '[[:space:]]-mfpu=[[:space:]]+vfpv3-d16([[:space:]]|$)' "${target_options}"
    require_text '-mfloat-abi=hard' '[[:space:]]-mfloat-abi=[[:space:]]+hard([[:space:]]|$)' "${target_options}"
    require_text '32-bit ARM ELF' 'Class:[[:space:]]+ELF32' "${elf_header}"
    require_text 'ARM EABI hard-float flags' 'Flags:.*hard-float ABI' "${elf_header}"
    require_text 'ARMv7 attributes' 'Tag_CPU_arch:[[:space:]]+v7' "${attributes}"
    require_text 'VFPv3-D16 attributes' 'Tag_FP_arch:[[:space:]]+VFPv3-D16' "${attributes}"
    reject_instruction 'hardware divide instructions' '[[:space:]](sdiv|udiv)[[:space:]]'
    reject_instruction 'VFPv4 fused multiply instructions' '[[:space:]]v(fma|fms|fnma|fnms)([.]|[[:space:]])'
    ;;
  x86)
    require_text '-march=i486' '[[:space:]]-march=[[:space:]]+i486([[:space:]]|$)' "${target_options}"
    require_text '32-bit x86 ELF' 'Class:[[:space:]]+ELF32' "${elf_header}"
    require_text 'Intel 80386 ELF machine' 'Machine:[[:space:]]+Intel 80386' "${elf_header}"
    reject_instruction 'i586+, MMX, or SSE instructions' '(%[xyz]mm[0-9]+|%mm[0-7]|[[:space:]](cmov[a-z]*|fcmov[a-z]*|cmpxchg8b|sysenter|syscall)[[:space:]])'
    ;;
  amd64)
    require_text '-march=x86-64' '[[:space:]]-march=[[:space:]]+x86-64([[:space:]]|$)' "${target_options}"
    require_text '64-bit x86 ELF' 'Class:[[:space:]]+ELF64' "${elf_header}"
    require_text 'x86-64 ELF machine' 'Machine:[[:space:]]+Advanced Micro Devices X86-64' "${elf_header}"
    reject_instruction 'AVX, AVX-512, or CET instructions' '(%[yz]mm[0-9]+|[[:space:]](v(add|sub|mul|div|max|min|mov|xor|and|or|p|broadcast|blend|cvt|extract|insert|perm|round|sqrt|test|zero|fmadd|fmsub|fnmadd|fnmsub)[a-z0-9.]*|rdssp[a-z]*|incssp[a-z]*|wrss[a-z]*|saveprevssp|rstorssp|setssbsy|clrssbsy)[[:space:]])'
    ;;
  mips|mipsel)
    require_text '-march=mips32' '[[:space:]]-march=ISA[[:space:]]+mips32([[:space:]]|$)' "${target_options}"
    require_text '-mabi=32' '[[:space:]]-mabi=ABI[[:space:]]+32([[:space:]]|$)' "${target_options}"
    require_text 'soft-float enabled' '[[:space:]]-msoft-float[[:space:]]+\[enabled\]' "${target_options}"
    require_text '32-bit MIPS ELF' 'Class:[[:space:]]+ELF32' "${elf_header}"
    require_text 'MIPS32 o32 flags' 'Flags:.*o32, mips32' "${elf_header}"
    if [[ ${target} == mips ]]; then
      require_text 'big-endian ELF' "Data:[[:space:]]+2's complement, big endian" "${elf_header}"
    else
      require_text 'little-endian ELF' "Data:[[:space:]]+2's complement, little endian" "${elf_header}"
    fi
    reject_instruction 'MIPS32r2+ instructions' '[[:space:]](di|ei|ext|ins|rdhwr|rotr|rotrv|seb|seh|synci|wsbh)[[:space:]]'
    ;;
esac

echo "compatibility check passed: ${target}"
