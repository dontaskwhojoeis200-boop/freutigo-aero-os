#!/usr/bin/env bash
# End-to-end installation test in QEMU:
#   1. boot the installer ISO with a blank disk and an AERO_AUTO answers
#      disk; freutigo-install runs unattended (real downloads from
#      cache.nixos.org) and powers off;
#   2. boot the installed disk without the ISO; the installed system prints
#      a boot report and FREUTIGO-BOOT-OK on the serial port and powers off.
#
# Usage: scripts/e2e-install-test.sh --iso PATH [--firmware uefi|bios]
#                                    [--desktop] [--workdir DIR]
# Needs: qemu-system-x86_64 + qemu-img, KVM, mkfs.fat + mcopy (mtools),
#        OVMF (UEFI), network access for the guest.
set -euo pipefail

ISO=""; FIRMWARE=uefi; DESKTOP=no; WORK=""
INSTALL_TIMEOUT=${INSTALL_TIMEOUT:-}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-900}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO="$2"; shift 2 ;;
    --firmware) FIRMWARE="$2"; shift 2 ;;
    --desktop) DESKTOP=yes; shift ;;
    --workdir) WORK="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -f "$ISO" ]] || { echo "error: --iso PATH required" >&2; exit 2; }
# Minimal installs download ~1 GB, the desktop several GB.
[[ -n "$INSTALL_TIMEOUT" ]] || INSTALL_TIMEOUT=$([[ $DESKTOP == yes ]] && echo 4200 || echo 2400)
WORK=${WORK:-$(mktemp -d)}
mkdir -p "$WORK"
echo "e2e: firmware=$FIRMWARE desktop=$DESKTOP workdir=$WORK"

# ---- answers disk ------------------------------------------------------------
cat > "$WORK/answers.env" <<EOF
LOCALE=en_US.UTF-8
KEYMAP=us
TIMEZONE=UTC
HOSTNAME=freutigo-e2e
USERNAME=tester
FULLNAME=E2E Tester
PASSWORD=e2e-password
GPU_PROFILE=auto
DESKTOP=$DESKTOP
DESKTOP_MODE=aero
STEAM=no
FIRMWARE=auto
DISK_MODE=erase
DISK=/dev/vda
CONFIRM_ERASE=/dev/vda
REBOOT=poweroff
E2E_SERIAL_MARKER=yes
EOF
rm -f "$WORK/auto.img"
mkfs.fat -C -n AERO_AUTO "$WORK/auto.img" 4096 >/dev/null
mcopy -i "$WORK/auto.img" "$WORK/answers.env" ::answers.env

rm -f "$WORK/disk.qcow2"
qemu-img create -q -f qcow2 "$WORK/disk.qcow2" 40G

common=(
  -machine "q35,accel=kvm" -cpu host -smp 2 -m 4096
  -display none -vga std
  -nic "user,model=virtio-net-pci"
  -drive "file=$WORK/disk.qcow2,if=virtio,format=qcow2"
)
if [[ $FIRMWARE == uefi ]]; then
  : "${OVMF_CODE:?set OVMF_CODE to OVMF_CODE.fd}"; : "${OVMF_VARS:?set OVMF_VARS to OVMF_VARS.fd}"
  install -m 644 "$OVMF_VARS" "$WORK/OVMF_VARS.fd"
  common+=(
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$WORK/OVMF_VARS.fd"
  )
fi

# Run QEMU with a timeout while printing the newest serial output once a
# minute, so CI logs show where a slow or stuck run is.
run_qemu() {  # LABEL TIMEOUT SERIAL_LOG qemu-args...
  local label=$1 limit=$2 serial=$3; shift 3
  : > "$serial"
  timeout "$limit" qemu-system-x86_64 "$@" -serial "file:$serial" &
  local pid=$! elapsed=0 last=""
  while kill -0 "$pid" 2>/dev/null; do
    sleep 10; elapsed=$((elapsed + 10))
    if (( elapsed % 60 == 0 )); then
      last=$(tail -n 3 "$serial" 2>/dev/null | tr -d '\r' | cut -c1-160)
      echo "e2e[$label] ${elapsed}s: ${last//$'\n'/ | }"
    fi
  done
  wait "$pid"
}

# ---- phase 1: install ----------------------------------------------------------
echo "e2e: phase 1 — installing from ISO (timeout ${INSTALL_TIMEOUT}s)"
start=$(date +%s)
set +e
run_qemu install "$INSTALL_TIMEOUT" "$WORK/serial-install.log" "${common[@]}" \
  -drive "file=$WORK/auto.img,if=virtio,format=raw,readonly=on" \
  -cdrom "$ISO" -boot order=d
rc=$?
set -e
echo "e2e: install phase exited rc=$rc after $(( $(date +%s) - start ))s"
grep -a "FREUTIGO-AUTOINSTALL\|^\[.*\] \|error" "$WORK/serial-install.log" | tail -n 40 || true
if ! grep -aq "FREUTIGO-AUTOINSTALL success" "$WORK/serial-install.log"; then
  echo "e2e: FAIL — installation did not report success" >&2
  tail -n 120 "$WORK/serial-install.log" >&2 || true
  exit 1
fi

# ---- phase 2: boot the installed disk --------------------------------------------
echo "e2e: phase 2 — booting the installed disk (timeout ${BOOT_TIMEOUT}s)"
start=$(date +%s)
set +e
run_qemu boot "$BOOT_TIMEOUT" "$WORK/serial-boot.log" "${common[@]}" -boot order=c
rc=$?
set -e
echo "e2e: boot phase exited rc=$rc after $(( $(date +%s) - start ))s"
grep -a "FREUTIGO-REPORT" "$WORK/serial-boot.log" || true
if ! grep -aq "FREUTIGO-BOOT-OK" "$WORK/serial-boot.log"; then
  echo "e2e: FAIL — installed system did not report a successful boot" >&2
  tail -n 80 "$WORK/serial-boot.log" >&2 || true
  exit 1
fi
failed=$(grep -a "FREUTIGO-REPORT failed-units=" "$WORK/serial-boot.log" | sed 's/.*=//' | tr -d '\r' | tail -1)
if [[ "${failed:-1}" != "0" ]]; then
  echo "e2e: FAIL — installed system booted with failed systemd units" >&2
  exit 1
fi
echo "e2e: PASS (firmware=$FIRMWARE desktop=$DESKTOP)"
