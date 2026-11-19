#!/usr/bin/env bash
# Fixture tests for scripts/detect-gpu-profile.sh. No hardware needed.
# Builds fake sysfs trees, modules.alias and kernel logs in a temp dir.
#
# Usage: tests/gpu-detect/run.sh [path/to/detect-gpu-profile.sh]
set -euo pipefail

DETECT=${1:-$(cd "$(dirname "$0")/../.." && pwd)/scripts/detect-gpu-profile.sh}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Minimal modules.alias mirroring the real kernel's format.
cat > "$WORK/modules.alias" <<'EOF'
alias pci:v00001002d00006811sv*sd*bc*sc*i* radeon
alias pci:v00001002d00006811sv*sd*bc*sc*i* amdgpu
alias pci:v00001002d00006819sv*sd*bc*sc*i* radeon
alias pci:v00001002d00006819sv*sd*bc*sc*i* amdgpu
alias pci:v00001002d00006610sv*sd*bc*sc*i* radeon
alias pci:v00001002d00006610sv*sd*bc*sc*i* amdgpu
alias pci:v00001002d0000682Bsv*sd*bc*sc*i* radeon
alias pci:v00001002d0000682Bsv*sd*bc*sc*i* amdgpu
alias pci:v00001002d0000683Dsv*sd*bc*sc*i* radeon
alias pci:v00001002d0000683Dsv*sd*bc*sc*i* amdgpu
alias pci:v00001002d0000683Fsv*sd*bc*sc*i* radeon
alias pci:v00001002d0000683Fsv*sd*bc*sc*i* amdgpu
alias pci:v00001002d000067DFsv*sd*bc*sc*i* amdgpu
alias pci:v00001002d000068B8sv*sd*bc*sc*i* radeon
alias pci:v000010DEd*sv*sd*bc03sc*i* nouveau
EOF

# mkgpu CASE SLOT VENDOR DEVICE DRIVER [CLASS]
mkgpu() {
  local d="$WORK/$1/sys/$2"
  mkdir -p "$d" "$WORK/$1/drivers/$5"
  echo "${6:-0x030000}" > "$d/class"
  echo "0x$3" > "$d/vendor"
  echo "0x$4" > "$d/device"
  [[ "$5" == none ]] || ln -s "../../drivers/$5" "$d/driver"
}
mkother() {  # a non-GPU PCI device that must be ignored
  local d="$WORK/$1/sys/$2"; mkdir -p "$d"
  echo 0x060000 > "$d/class"; echo 0x8086 > "$d/vendor"; echo 0x0150 > "$d/device"
}

pass=0; failn=0
# check CASE EXPECTED_PROFILE EXPECTED_NVIDIA_OPEN EXPECTED_SUPPORT [ALIAS=yes|no] [EXPECTED_VRAM_MIB]
check() {
  local c=$1 want_p=$2 want_o=$3 want_s=$4 alias=${5:-yes} want_v=${6-skip}
  mkdir -p "$WORK/$c/sys"
  local out
  out=$(FREUTIGO_SYSFS_PCI="$WORK/$c/sys" \
        FREUTIGO_MODULES_ALIAS="$([[ $alias == yes ]] && echo "$WORK/modules.alias" || echo "$WORK/missing")" \
        FREUTIGO_DMESG_FILE="$WORK/$c/dmesg" \
        bash "$DETECT" --shell --quiet)
  local PROFILE NVIDIA_OPEN SUPPORT GPU REASON VRAM_MIB
  eval "$out"
  if [[ "$PROFILE" == "$want_p" && "$NVIDIA_OPEN" == "$want_o" && "$SUPPORT" == "$want_s" ]] &&
     [[ "$want_v" == skip || "$VRAM_MIB" == "$want_v" ]]; then
    pass=$((pass + 1)); printf '  ok   %-34s -> %s%s\n' "$c" "$PROFILE" "${VRAM_MIB:+ (${VRAM_MIB} MiB)}"
  else
    failn=$((failn + 1))
    printf '  FAIL %-34s got %s/%s/%s vram=%s want %s/%s/%s vram=%s\n     %s\n' "$c" "$PROFILE" "$NVIDIA_OPEN" "$SUPPORT" "$VRAM_MIB" "$want_p" "$want_o" "$want_s" "$want_v" "$REASON"
  fi
}

# Reference hardware -------------------------------------------------------
mkgpu r9-270 0000:01:00.0 1002 6811 radeon; mkother r9-270 0000:00:00.0; touch "$WORK/r9-270/dmesg"
mkgpu hd-7850 0000:01:00.0 1002 6819 radeon; touch "$WORK/hd-7850/dmesg"
mkgpu hd-7850-amdgpu-bound 0000:01:00.0 1002 6819 amdgpu; touch "$WORK/hd-7850-amdgpu-bound/dmesg"
mkgpu gtx-660 0000:01:00.0 10de 11c0 nouveau
echo "[    2.1] nouveau 0000:01:00.0: NVIDIA GK106 (0e6000a1)" > "$WORK/gtx-660/dmesg"
mkgpu gtx-660-no-log 0000:01:00.0 10de 11c0 none; touch "$WORK/gtx-660-no-log/dmesg"

# Radeon R7 250 family (GCN 1.0): Oland and Cape Verde variants ----------------
mkgpu r7-250-oland 0000:01:00.0 1002 6610 radeon
echo "[    3.2] radeon 0000:01:00.0: VRAM: 1024M 0x0000000000000000 - 0x000000003FFFFFFF (1024M used)" > "$WORK/r7-250-oland/dmesg"
mkgpu r7-250-capeverde 0000:01:00.0 1002 682b radeon; touch "$WORK/r7-250-capeverde/dmesg"
mkgpu r7-250x 0000:01:00.0 1002 683d radeon
echo "radeon 0000:01:00.0: VRAM: 2048M 0x0000000000000000 - 0x000000007FFFFFFF (2048M used)" > "$WORK/r7-250x/dmesg"
mkgpu r7-250e-amdgpu-bound 0000:01:00.0 1002 683f amdgpu; touch "$WORK/r7-250e-amdgpu-bound/dmesg"
echo 2147483648 > "$WORK/r7-250e-amdgpu-bound/sys/0000:01:00.0/mem_info_vram_total"

# Other hardware -------------------------------------------------------------
mkgpu rx-580 0000:01:00.0 1002 67df amdgpu; touch "$WORK/rx-580/dmesg"
mkgpu hd-5770 0000:01:00.0 1002 68b8 radeon; touch "$WORK/hd-5770/dmesg"
mkgpu gtx-1060 0000:01:00.0 10de 1c03 nouveau
echo "nouveau 0000:01:00.0: NVIDIA GP106 (136000a1)" > "$WORK/gtx-1060/dmesg"
mkgpu rtx-3060 0000:01:00.0 10de 2503 nouveau
echo "nouveau 0000:01:00.0: NVIDIA GA106 (b66000a1)" > "$WORK/rtx-3060/dmesg"
mkgpu intel-only 0000:00:02.0 8086 0152 i915; touch "$WORK/intel-only/dmesg"
mkgpu qemu-virtio 0000:00:01.0 1af4 1050 virtio-pci; touch "$WORK/qemu-virtio/dmesg"
mkgpu igpu-plus-r9-270 0000:00:02.0 8086 0152 i915
mkgpu igpu-plus-r9-270 0000:01:00.0 1002 6811 radeon; touch "$WORK/igpu-plus-r9-270/dmesg"
mkdir -p "$WORK/no-gpu/sys"; mkother no-gpu 0000:00:00.0; touch "$WORK/no-gpu/dmesg"

echo "GPU detection fixture tests ($DETECT)"
check r9-270                 amd-gcn-legacy    - supported
check hd-7850                amd-gcn-legacy    - supported
check hd-7850-amdgpu-bound   amd-gcn-legacy    - supported
check gtx-660                nvidia-kepler-oss - supported
check gtx-660-no-log         nvidia-kepler-oss - supported
check rx-580                 amd-modern        - supported
check hd-5770                amd-modern        - unsupported
check gtx-1060               nvidia-modern     false supported
check rtx-3060               nvidia-modern     true  supported
check intel-only             intel             - supported
check qemu-virtio            virtual-machine   - supported
check igpu-plus-r9-270       amd-gcn-legacy    - supported
check no-gpu                 none              - none
check r7-250-oland           amd-gcn-legacy    - supported yes 1024
check r7-250-capeverde       amd-gcn-legacy    - supported yes ""
check r7-250x                amd-gcn-legacy    - supported yes 2048
check r7-250e-amdgpu-bound   amd-gcn-legacy    - supported yes 2048
# Without modules.alias the SI/CIK device-ID table must give the same answer.
check r9-270                 amd-gcn-legacy    - supported no
check hd-7850                amd-gcn-legacy    - supported no
check rx-580                 amd-modern        - supported no
check r7-250-oland           amd-gcn-legacy    - supported no 1024
check r7-250-capeverde       amd-gcn-legacy    - supported no
check r7-250x                amd-gcn-legacy    - supported no

echo "$pass passed, $failn failed"
[[ $failn -eq 0 ]]
