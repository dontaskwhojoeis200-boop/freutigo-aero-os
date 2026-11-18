#!/usr/bin/env bash
# Run Freutigo Aero OS in QEMU/KVM.
#
#   scripts/test-vm.sh            build and run the virtual-machine host
#                                 (login: freutigo / freutigo)
#   scripts/test-vm.sh --iso [PATH] [--bios]
#                                 boot an installer ISO (default: newest in
#                                 dist/) with UEFI (OVMF) or legacy BIOS,
#                                 attached to a scratch 32 GiB disk.
#
# A VM boot is "Booted in VM" on the verification ladder; it is never
# evidence of real-GPU compatibility.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [[ "${1:-}" != "--iso" ]]; then
  out=$(nix build --no-link --print-out-paths .#nixosConfigurations.virtual-machine.config.system.build.vm)
  exec "$out"/bin/run-*-vm
fi

shift
ISO=""; FIRMWARE=uefi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bios) FIRMWARE=bios; shift ;;
    *) ISO="$1"; shift ;;
  esac
done
if [[ -z "$ISO" ]]; then
  ISO=$(find dist -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi
[[ -f "$ISO" ]] || { echo "error: no ISO found; run scripts/build-iso.sh first" >&2; exit 1; }

mkdir -p .vm
DISK=.vm/scratch-disk.qcow2
[[ -f "$DISK" ]] || qemu-img create -f qcow2 "$DISK" 32G

args=(
  -enable-kvm -cpu host -smp 2 -m 4096
  -drive "file=$DISK,if=virtio,format=qcow2"
  -cdrom "$ISO" -boot d
  -nic user,model=virtio-net-pci
  -vga none -device virtio-vga-gl -display gtk,gl=on
  -audiodev pipewire,id=snd0 -device intel-hda -device hda-output,audiodev=snd0
)

if [[ $FIRMWARE == uefi ]]; then
  OVMF_CODE=$(nix build --no-link --print-out-paths --inputs-from . nixpkgs#OVMF.fd)/FV/OVMF_CODE.fd
  OVMF_VARS_SRC=${OVMF_CODE%_CODE.fd}_VARS.fd
  [[ -f .vm/OVMF_VARS.fd ]] || install -m 644 "$OVMF_VARS_SRC" .vm/OVMF_VARS.fd
  args+=(
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=.vm/OVMF_VARS.fd"
  )
fi

echo "Booting $ISO ($FIRMWARE firmware)" >&2
exec qemu-system-x86_64 "${args[@]}"
