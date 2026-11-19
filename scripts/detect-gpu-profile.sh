#!/usr/bin/env bash
# freutigo-detect-gpu — choose a Freutigo GPU profile from the running hardware.
#
# Detection is data-driven where possible:
#  - AMD: a GPU claimable by BOTH `radeon` and `amdgpu` (kernel modules.alias)
#    is GCN 1.0/1.1 (Southern/Sea Islands) -> amd-gcn-legacy. amdgpu-only
#    -> amd-modern. radeon-only -> pre-GCN (TeraScale): no Vulkan, unsupported.
#  - NVIDIA: chipset family from nouveau's kernel log ("NVIDIA GK106"),
#    falling back to PCI device-ID ranges (heuristic).
#  - Intel / virtual GPUs by vendor ID.
# With several GPUs, a discrete AMD/NVIDIA card wins over Intel/virtual.
#
# Output (default): the profile name. With --shell, KEY=value lines:
#   PROFILE, NVIDIA_OPEN (true/false/-), SUPPORT (supported/experimental/
#   unsupported/none), GPU (description), REASON, VRAM_MIB (empty when not
#   reliably known; from amdgpu sysfs or the radeon/amdgpu "VRAM: <n>M" log).
# All findings are also explained on stderr unless --quiet.
#
# Test hooks (environment): FREUTIGO_SYSFS_PCI, FREUTIGO_MODULES_ALIAS,
# FREUTIGO_DMESG_FILE.
set -euo pipefail

MODE=name
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --shell) MODE=shell ;;
    --quiet) QUIET=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

SYSFS_PCI=${FREUTIGO_SYSFS_PCI:-/sys/bus/pci/devices}

say() { [[ $QUIET -eq 1 ]] || echo "$*" >&2; }

find_modules_alias() {
  if [[ -n "${FREUTIGO_MODULES_ALIAS:-}" ]]; then echo "$FREUTIGO_MODULES_ALIAS"; return; fi
  local k; k=$(uname -r)
  for f in "/run/booted-system/kernel-modules/lib/modules/$k/modules.alias" \
           "/run/current-system/kernel-modules/lib/modules/$k/modules.alias" \
           "/lib/modules/$k/modules.alias"; do
    [[ -r "$f" ]] && { echo "$f"; return; }
  done
  echo ""
}
MODULES_ALIAS=$(find_modules_alias)

kernel_log() {
  if [[ -n "${FREUTIGO_DMESG_FILE:-}" ]]; then cat "$FREUTIGO_DMESG_FILE"; return; fi
  dmesg 2>/dev/null || journalctl -k -b --no-pager 2>/dev/null || true
}
KLOG=$(kernel_log)

# Does kernel module $1 declare support for PCI vendor $2 device $3?
module_claims() {
  local mod=$1 ven=$2 dev=$3
  [[ -n "$MODULES_ALIAS" && -r "$MODULES_ALIAS" ]] || return 2
  grep -qiE "^alias pci:v0000${ven}d0000${dev}sv.* ${mod}\$" "$MODULES_ALIAS"
}

hex() { printf '%d' "0x$1"; }

# Fallback when modules.alias is unavailable: SI/CIK device-ID ranges.
amd_is_gcn_legacy_by_id() {
  local d; d=$(hex "$1")
  local -a ranges=(
    0x6780 0x679F  # Tahiti (HD 7900, R9 280)
    0x6800 0x681F  # Pitcairn / Curacao (HD 7800, R9 270/370)
    0x6820 0x683F  # Cape Verde (HD 7700)
    0x6600 0x663F  # Oland
    0x6660 0x667F  # Hainan
    0x6640 0x665F  # Bonaire (CIK)
    0x67A0 0x67BF  # Hawaii (CIK)
    0x1304 0x131D  # Kaveri APU (CIK)
    0x9830 0x983F  # Kabini APU (CIK)
    0x9850 0x985F  # Mullins APU (CIK)
  )
  local i
  for ((i = 0; i < ${#ranges[@]}; i += 2)); do
    (( d >= ranges[i] && d <= ranges[i + 1] )) && return 0
  done
  return 1
}

nvidia_family_from_log() {
  # nouveau 0000:01:00.0: NVIDIA GK106 (0e6000a1)
  local slot=$1
  grep -oE "nouveau ${slot}: NVIDIA (G[A-Z]+[0-9]+|NV[0-9A-F]+|TU[0-9]+|GA[0-9]+|AD[0-9]+|GB[0-9]+|GH[0-9]+)" <<<"$KLOG" |
    head -1 | awk '{print $NF}' || true
}

# Heuristic NVIDIA generation from device ID when nouveau gave no name.
nvidia_family_by_id() {
  local d; d=$(hex "$1")
  if (( (d >= 0x0FC0 && d <= 0x0FFF) || (d >= 0x1000 && d <= 0x103F) ||
        (d >= 0x1180 && d <= 0x11FF) || (d >= 0x1280 && d <= 0x12BF) )); then
    echo "GK?"
  elif (( d >= 0x1E00 )); then
    echo "TU+?"
  elif (( d >= 0x1340 && d <= 0x1DFF )); then
    echo "GM/GP?"
  else
    echo ""
  fi
}

# VRAM in MiB for an AMD GPU: exact sysfs value when amdgpu is bound,
# otherwise the "VRAM: <n>M" line both radeon and amdgpu log at probe time.
amd_vram_mib() {
  local devdir=$1 slot=$2 v
  if [[ -r "$devdir/mem_info_vram_total" ]]; then
    v=$(cat "$devdir/mem_info_vram_total")
    echo $(( v / 1048576 )); return
  fi
  grep -oE "(radeon|amdgpu) ${slot}: (amdgpu: )?VRAM: [0-9]+M" <<<"$KLOG" |
    head -1 | grep -oE "[0-9]+M\$" | tr -d M || true
}

BEST_RANK=0
PROFILE=none; NVIDIA_OPEN=-; SUPPORT=none; GPU_DESC="no GPU detected"; REASON="no PCI display controller found"; VRAM_MIB=""

consider() {  # rank profile nvidia_open support desc reason [vram_mib]
  if (( $1 > BEST_RANK )); then
    BEST_RANK=$1; PROFILE=$2; NVIDIA_OPEN=$3; SUPPORT=$4; GPU_DESC=$5; REASON=$6; VRAM_MIB=${7:-}
  fi
}

shopt -s nullglob
for devdir in "$SYSFS_PCI"/*; do
  class=$(cat "$devdir/class" 2>/dev/null || echo "")
  [[ "$class" == 0x03* ]] || continue
  slot=${devdir##*/}
  ven=$(sed 's/^0x//' "$devdir/vendor" | tr 'a-f' 'A-F')
  dev=$(sed 's/^0x//' "$devdir/device" | tr 'a-f' 'A-F')
  drv="(none)"
  [[ -L "$devdir/driver" ]] && drv=$(basename "$(readlink "$devdir/driver")")
  desc="$slot [$ven:$dev] driver=$drv"
  say "found GPU: $desc"

  case "$ven" in
    1002)
      rc_r=0; module_claims radeon "$ven" "$dev" || rc_r=$?
      rc_a=0; module_claims amdgpu "$ven" "$dev" || rc_a=$?
      r=0; a=0
      [[ $rc_r -eq 0 ]] && r=1
      [[ $rc_a -eq 0 ]] && a=1
      if [[ $rc_r -eq 2 ]]; then
        say "  modules.alias unavailable; using SI/CIK device-ID table"
        if amd_is_gcn_legacy_by_id "$dev"; then r=1; a=1; else a=1; fi
      fi
      vram=$(amd_vram_mib "$devdir" "$slot")
      [[ -n "$vram" ]] && { desc="$desc vram=${vram}MiB"; say "  VRAM: ${vram} MiB"; }
      if (( r && a )); then
        consider 30 amd-gcn-legacy - supported "AMD GCN 1.0/1.1 $desc" "claimable by radeon and amdgpu -> Southern/Sea Islands (e.g. R7 250, HD 7850, R9 270); force amdgpu for Vulkan (RADV)" "$vram"
      elif (( a )); then
        consider 30 amd-modern - supported "AMD GCN3+/RDNA $desc" "claimable by amdgpu only" "$vram"
      else
        consider 25 amd-modern - unsupported "AMD pre-GCN $desc" "radeon-only (TeraScale or older): OpenGL via radeon, NO Vulkan; not a supported Freutigo GPU" "$vram"
      fi
      ;;
    10DE)
      fam=$(nvidia_family_from_log "$slot")
      src="nouveau kernel log"
      if [[ -z "$fam" ]]; then fam=$(nvidia_family_by_id "$dev"); src="device-ID heuristic"; fi
      case "$fam" in
        GK*) consider 30 nvidia-kepler-oss - supported "NVIDIA Kepler ($fam) $desc" "Kepler per $src: nouveau + NVK (proprietary 470 is an optional experimental profile)" ;;
        GM*|GP*|GV*) consider 30 nvidia-modern false supported "NVIDIA Maxwell/Pascal/Volta ($fam) $desc" "per $src: proprietary driver with closed kernel module (open module needs Turing+)" ;;
        TU*|GA*|AD*|GB*|GH*) consider 30 nvidia-modern true supported "NVIDIA Turing+ ($fam) $desc" "per $src: proprietary driver with open kernel module" ;;
        "") consider 20 nvidia-kepler-oss - unsupported "NVIDIA (unknown family) $desc" "family not identifiable; nouveau profile chosen as the safe default, verify manually" ;;
        *) consider 20 nvidia-kepler-oss - unsupported "NVIDIA pre-Kepler ($fam) $desc" "pre-Kepler: nouveau OpenGL only, no NVK Vulkan; not a supported Freutigo GPU" ;;
      esac
      ;;
    8086)
      consider 15 intel - supported "Intel integrated $desc" "Intel vendor ID" ;;
    1AF4|1234|1B36|15AD|80EE)
      consider 10 virtual-machine - supported "Virtual GPU $desc" "virtual display adapter vendor ID" ;;
    *)
      consider 5 none - unsupported "Unknown GPU $desc" "unrecognised vendor; choose a profile manually" ;;
  esac
done

say "selected profile: $PROFILE ($SUPPORT) — $REASON"

if [[ $MODE == shell ]]; then
  printf 'PROFILE=%q\nNVIDIA_OPEN=%q\nSUPPORT=%q\nGPU=%q\nREASON=%q\nVRAM_MIB=%q\n' \
    "$PROFILE" "$NVIDIA_OPEN" "$SUPPORT" "$GPU_DESC" "$REASON" "$VRAM_MIB"
else
  echo "$PROFILE"
fi
