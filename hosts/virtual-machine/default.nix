# QEMU/KVM development VM. Run with scripts/test-vm.sh.
#
# Uses the NixOS qemu-vm module via `config.system.build.vm`, which supplies
# its own disk and boot handling, so no bootloader is configured here.
{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../common/placeholder-hardware.nix
  ];

  networking.hostName = "freutigo-vm";

  freutigo.hardware.gpuProfile = "virtual-machine";
  freutigo.desktop.enable = true;
  freutigo.desktop.mode = lib.mkDefault "aero";
  freutigo.boot.mode = "none";
  # Steam is not needed to test the desktop in a VM.
  freutigo.gaming.steam.enable = false;

  # Development VM only: known password, documented in docs/BUILD.md.
  freutigo.user.initialPassword = "freutigo";

  # Settings applied only when built as `system.build.vm`.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 4096;
    cores = 2; # mirror the dual-core reference CPU
    diskSize = 16384;
    resolution = {
      x = 1920;
      y = 1080;
    };
    qemu.options = [
      "-vga none"
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };
}
