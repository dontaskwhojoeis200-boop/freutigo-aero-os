#!/usr/bin/env bash
# freutigo-gpu-diagnostics — Freutigo Aero OS graphics diagnostic (section 5.5)
#
# Reports: detected GPU(s), bound kernel driver, Mesa/NVIDIA driver version,
# OpenGL renderer, Vulkan implementation + API version, required Vulkan
# extensions, VRAM (where accurately measurable), display resolution,
# session type, CPU baseline compatibility.
#
# Exit status: 0 = hardware acceleration verified, 1 = problems found,
#              2 = could not run checks (missing tools / no GPU).
#
# Usage: freutigo-gpu-diagnostics [--quiet] [--required-ext EXT ...]
set -euo pipefail

# Vulkan device extensions the Freutigo desktop + Cat Arena (Vulkan 1.1
# baseline) need. Extend with --required-ext.
REQUIRED_VK_EXTS=(VK_KHR_swapchain)
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --required-ext) REQUIRED_VK_EXTS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

PROBLEMS=0
WARNINGS=0

if [[ -t 1 ]]; then
  C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_H=$'\e[1;36m'; C_0=$'\e[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_H=""; C_0=""
fi

section() { echo; echo "${C_H}== $* ==${C_0}"; }
info()    { printf '  %-22s %s\n' "$1" "$2"; }
ok()      { echo "  ${C_OK}[ OK ]${C_0} $*"; }
warn()    { echo "  ${C_WARN}[WARN]${C_0} $*"; WARNINGS=$((WARNINGS + 1)); }
fail()    { echo "  ${C_ERR}[FAIL]${C_0} $*"; PROBLEMS=$((PROBLEMS + 1)); }
have()    { command -v "$1" >/dev/null 2>&1; }

# --------------------------------------------------------------------------
section "System"
info "Freutigo version" "$(cat /etc/freutigo/version 2>/dev/null || echo 'n/a (not a Freutigo system)')"
info "GPU profile" "$(cat /etc/freutigo/gpu-profile 2>/dev/null || echo 'n/a')"
info "Desktop mode" "$(cat /etc/freutigo/desktop-mode 2>/dev/null || echo 'n/a')"
info "Kernel" "$(uname -r)"
info "Session type" "${XDG_SESSION_TYPE:-unknown (not run from a graphical session?)}"
info "Desktop" "${XDG_CURRENT_DESKTOP:-unknown}"

# CPU baseline: the reference Pentium G2020 has no AVX. Report, so users can
# tell whether a game/tool failing with SIGILL is an instruction-set issue.
cpu_model=$(awk -F: '/^model name/ {gsub(/^ +/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
cpu_flags=$(awk -F: '/^flags/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
info "CPU" "${cpu_model:-unknown}"
for f in sse4_2 popcnt avx avx2; do
  if [[ " $cpu_flags " == *" $f "* ]]; then info "  $f" "yes"; else info "  $f" "no"; fi
done

# --------------------------------------------------------------------------
section "GPU hardware and kernel driver"
shopt -s nullglob
gpu_found=0
declare -A DRIVER_OF=()
for dev in /sys/bus/pci/devices/*; do
  class=$(cat "$dev/class" 2>/dev/null || echo "")
  # 0x0300xx VGA, 0x0302xx 3D controller, 0x0380xx display controller
  [[ "$class" == 0x03* ]] || continue
  gpu_found=1
  slot=${dev##*/}
  vendor=$(cat "$dev/vendor"); device=$(cat "$dev/device")
  driver="(none)"
  [[ -e "$dev/driver" ]] && driver=$(basename "$(readlink -f "$dev/driver")")
  DRIVER_OF[$slot]=$driver
  name="$vendor:$device"
  if have lspci; then
    name=$(lspci -s "$slot" -mm 2>/dev/null | awk -F'"' '{print $4" "$6}' || echo "$name")
  fi
  info "PCI $slot" "$name [$vendor:$device]"
  info "  kernel driver" "$driver"

  case "$vendor:$driver" in
    0x1002:amdgpu)  ok "AMD GPU bound to amdgpu (Vulkan via RADV possible)" ;;
    0x1002:radeon)
      fail "AMD GPU bound to legacy 'radeon' driver: NO Vulkan. For GCN 1.0/1.1 use the amd-gcn-legacy profile (amdgpu.si_support=1 / cik_support=1)." ;;
    0x10de:nouveau) ok "NVIDIA GPU bound to nouveau (Vulkan via NVK possible)" ;;
    0x10de:nvidia)  ok "NVIDIA GPU bound to proprietary nvidia driver" ;;
    0x8086:i915|0x8086:xe) ok "Intel GPU bound to $driver" ;;
    *:virtio-pci|*:virtio_gpu|0x1af4:*) warn "Virtual GPU ($driver): results do not prove real-hardware compatibility" ;;
    *:"(none)")     fail "No kernel driver bound to this GPU" ;;
    *)              warn "Unrecognised vendor/driver combination: $vendor/$driver" ;;
  esac

  # VRAM: only report values the kernel measures exactly.
  for card in "$dev"/drm/card*; do
    if [[ -r "$card/device/mem_info_vram_total" ]]; then
      total=$(cat "$card/device/mem_info_vram_total"); used=$(cat "$card/device/mem_info_vram_used" 2>/dev/null || echo 0)
      info "  VRAM (amdgpu)" "$((total / 1048576)) MiB total, $((used / 1048576)) MiB used"
      if (( total < 2 * 1024 * 1024 * 1024 )); then
        warn "Less than 2 GiB VRAM: test Aero Lite mode and lower game texture settings"
      fi
    fi
  done
done
if [[ $gpu_found -eq 0 ]]; then
  fail "No PCI display controller found"
fi
for slot in "${!DRIVER_OF[@]}"; do
  case "${DRIVER_OF[$slot]}" in
    nvidia)
      if have nvidia-smi; then
        info "VRAM (nvidia-smi)" "$(nvidia-smi --query-gpu=memory.total,memory.used --format=csv,noheader 2>/dev/null || echo n/a)"
      fi ;;
    nouveau)
      info "VRAM (nouveau)" "not accurately measurable via sysfs; see 'glxinfo -B' estimate below" ;;
  esac
done

# --------------------------------------------------------------------------
section "OpenGL"
if ! have glxinfo; then
  warn "glxinfo not installed (package: mesa-demos)"
elif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  warn "No DISPLAY/WAYLAND_DISPLAY: run from inside the desktop session for OpenGL checks"
else
  glx=$(glxinfo -B 2>&1 || true)
  renderer=$(sed -n 's/^ *OpenGL renderer string: //p' <<<"$glx" | head -1)
  version=$(sed -n 's/^ *OpenGL core profile version string: //p' <<<"$glx" | head -1)
  [[ -z "$version" ]] && version=$(sed -n 's/^ *OpenGL version string: //p' <<<"$glx" | head -1)
  accel=$(sed -n 's/^ *Accelerated: //p' <<<"$glx" | head -1)
  vmem=$(sed -n 's/^ *Video memory: //p' <<<"$glx" | head -1)
  info "Renderer" "${renderer:-unknown}"
  info "Version" "${version:-unknown}"
  info "Accelerated" "${accel:-unknown}"
  [[ -n "$vmem" ]] && info "Video memory (driver)" "$vmem"
  if [[ "$renderer" == *llvmpipe* || "$renderer" == *softpipe* || "$accel" == "no" ]]; then
    fail "OpenGL is SOFTWARE rendered ($renderer). Hardware acceleration is not active."
  elif [[ -n "$renderer" ]]; then
    ok "Hardware OpenGL renderer active"
  else
    fail "Could not determine OpenGL renderer"
  fi
fi

# --------------------------------------------------------------------------
section "Vulkan"
if ! have vulkaninfo; then
  warn "vulkaninfo not installed (package: vulkan-tools)"
else
  vk=$(vulkaninfo --summary 2>&1 || true)
  if ! grep -q "deviceName" <<<"$vk"; then
    fail "No Vulkan devices enumerated. Loader output:"
    sed 's/^/      /' <<<"$vk" | head -15
  else
    # Print each physical device block from the summary.
    awk '/^GPU[0-9]+:/ {g=$1} /apiVersion|driverVersion|driverName|driverInfo|deviceType|deviceName/ {gsub(/^[ \t]+/, ""); print "  " g " " $0}' <<<"$vk"
    hw_dev=0
    while IFS= read -r line; do
      [[ "$line" == *PHYSICAL_DEVICE_TYPE_CPU* ]] || hw_dev=1
    done < <(grep "deviceType" <<<"$vk")
    if [[ $hw_dev -eq 1 ]]; then ok "Hardware Vulkan device present"; else fail "Only CPU (lavapipe) Vulkan devices found"; fi

    # Required extensions on GPU0 (full report needed for extension list).
    full=$(vulkaninfo 2>/dev/null || true)
    for ext in "${REQUIRED_VK_EXTS[@]}"; do
      if grep -q "^[[:space:]]*$ext" <<<"$full"; then ok "extension $ext"; else fail "extension $ext missing"; fi
    done
    api=$(grep -m1 "apiVersion" <<<"$vk" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
    if [[ -n "$api" ]]; then
      major=${api%%.*}; rest=${api#*.}; minor=${rest%%.*}
      if (( major > 1 || (major == 1 && minor >= 1) )); then
        ok "Vulkan API $api >= 1.1 (Cat Arena baseline) — still verify device features, not only the version"
      else
        fail "Vulkan API $api < 1.1"
      fi
    fi
  fi
fi

# --------------------------------------------------------------------------
section "Displays"
analog_connected=0
for status in /sys/class/drm/card*-*/status; do
  conn_dir=${status%/status}
  [[ "$(cat "$status")" == "connected" ]] || continue
  mode=$(head -1 "$conn_dir/modes" 2>/dev/null || echo "?")
  info "${conn_dir##*/}" "connected, preferred mode $mode"
  case "${conn_dir##*/}" in *-VGA-*|*-DVI-I-*) analog_connected=1 ;; esac
done
# amdgpu's DC display code has no analog support before Linux 6.19; SI/CIK
# cards (e.g. R7 250) must use the default legacy display path for VGA.
if [[ $analog_connected -eq 1 ]] && grep -qw "amdgpu.dc=1" /proc/cmdline 2>/dev/null; then
  kver=$(uname -r | cut -d. -f1-2)
  if [[ "$(printf '%s\n6.19\n' "$kver" | sort -V | head -1)" != "6.19" ]]; then
    warn "VGA/DVI-I connector in use with amdgpu.dc=1 on Linux $kver: analog output needs the legacy display path before 6.19 — remove amdgpu.dc=1"
  fi
fi
if have kscreen-doctor && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Output|Modes" | sed 's/^/  /' | head -10 || true
elif have xrandr && [[ -n "${DISPLAY:-}" ]]; then
  xrandr --current 2>/dev/null | grep -E " connected|\*" | sed 's/^/  /' || true
fi

# --------------------------------------------------------------------------
section "Summary"
if [[ $gpu_found -eq 0 ]]; then
  echo "  No GPU detected; nothing verified."; exit 2
fi
if (( PROBLEMS > 0 )); then
  echo "  ${C_ERR}$PROBLEMS problem(s)${C_0}, $WARNINGS warning(s). Hardware acceleration is NOT fully verified."
  echo "  See docs/HARDWARE.md and docs/RECOVERY.md (\"Broken graphics driver\")."
  exit 1
fi
echo "  ${C_OK}No problems found${C_0} ($WARNINGS warning(s))."
[[ $QUIET -eq 1 ]] || echo "  Note: a working desktop image alone does not prove driver health; this report checks the actual stack."
exit 0
