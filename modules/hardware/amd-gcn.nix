# AMD GCN 1.0 / 1.1 legacy profile — primary development GPU family.
# Southern Islands (GCN 1.0): Radeon R9 270 (Pitcairn/Curacao),
# HD 7850 (Pitcairn), R7 250 (Oland XT 6610; Cape Verde 682B, R7 250X 683D,
# R7 250E 683F), HD 7700/7900. Sea Islands (GCN 1.1): Bonaire, Hawaii, APUs.
#
# Linux 6.18 binds SI/CIK GPUs to the old `radeon` driver by default, which
# has no Vulkan. This profile forces `amdgpu` so Mesa's RADV driver works.
#
# Display outputs: on Linux < 6.19, amdgpu drives SI/CIK through its legacy
# (non-DC) display code by default, which supports analog VGA and DVI-I via
# the DAC encoders. amdgpu's newer DC display code only gained analog support
# in Linux 6.19, so `amdgpu.dc=1` is refused here on older kernels: it would
# leave VGA monitors (common on R7 250 boards) without a picture.
{ config, lib, ... }:
let
  enabled = config.freutigo.hardware.gpuProfile == "amd-gcn-legacy";
  kernelVersion = config.boot.kernelPackages.kernel.version;
  forcesDc = builtins.elem "amdgpu.dc=1" config.boot.kernelParams;
in
lib.mkIf enabled {
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

  assertions = [
    {
      assertion = !(forcesDc && lib.versionOlder kernelVersion "6.19");
      message = ''
        amd-gcn-legacy: "amdgpu.dc=1" is set, but Linux ${kernelVersion} has no
        analog (VGA / DVI-I) support in amdgpu's DC display code (added in 6.19).
        Monitors on VGA or DVI-I analog would get no picture (common on R7 250
        boards). Remove amdgpu.dc=1 or use a kernel >= 6.19.
      '';
    }
  ];
}
