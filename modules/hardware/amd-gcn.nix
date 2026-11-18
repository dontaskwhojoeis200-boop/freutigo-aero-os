# AMD GCN 1.0 / 1.1 legacy profile — primary development GPU.
# Targets: Radeon R9 270 (Curacao/Pitcairn, GCN 1.0), Radeon HD 7850
# (Pitcairn, GCN 1.0). Also covers other Southern/Sea Islands cards.
#
# By default the Linux kernel binds Southern Islands (SI) and Sea Islands (CIK)
# GPUs to the old `radeon` driver, which has no Vulkan support. This profile
# forces `amdgpu` so Mesa's RADV Vulkan driver works.
{ config, lib, ... }:
lib.mkIf (config.freutigo.hardware.gpuProfile == "amd-gcn-legacy") {
  # Adds amdgpu.si_support=1 amdgpu.cik_support=1 radeon.si_support=0
  # radeon.cik_support=0 to the kernel command line (NixOS module).
  hardware.amdgpu.legacySupport.enable = true;

  # Load amdgpu in the initrd: correct native resolution from early boot
  # and no window in which `radeon` could claim the device first.
  hardware.amdgpu.initrd.enable = true;

  # Vulkan: RADV ships in Mesa and is the only AMD Vulkan driver installed
  # (AMDVLK is intentionally not added). OpenGL: radeonsi (Mesa).
  # Xorg fallback uses the generic modesetting DDX on top of amdgpu.
  services.xserver.videoDrivers = [ "modesetting" ];

  # NOTE: analog VGA/DVI-I analog outputs are only supported by `radeon`.
  # Using amdgpu removes them; see docs/HARDWARE.md.
}
