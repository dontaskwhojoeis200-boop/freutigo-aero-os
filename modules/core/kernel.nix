{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.freutigo.kernel;
in
{
  options.freutigo.kernel = {
    packages = lib.mkOption {
      type = lib.types.raw;
      default = pkgs.linuxPackages;
      defaultText = lib.literalExpression "pkgs.linuxPackages";
      description = ''
        Kernel package set. Defaults to the NixOS Stable default LTS kernel
        (6.18 in NixOS 26.05). No custom patches or scheduler changes are
        applied until benchmarks justify them (F5).
      '';
    };
  };

  config = {
    boot.kernelPackages = lib.mkDefault cfg.packages;

    # CPU microcode and redistributable GPU/Wi-Fi firmware. Required for
    # AMD GCN (radeon/amdgpu firmware blobs) and most Wi-Fi adapters.
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
    hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

    # Security mitigations are left at kernel defaults deliberately
    # (Rule 7: no "mitigations=off" for small performance gains).
  };
}
