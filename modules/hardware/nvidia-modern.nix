# NVIDIA modern profile: current production driver.
# Default uses NVIDIA's open kernel module, which requires Turing (GTX 16xx /
# RTX 20xx) or newer. Maxwell/Pascal users must set
# freutigo.hardware.nvidia.openKernelModule = false.
{ config, lib, ... }:
let
  cfg = config.freutigo.hardware.nvidia;
in
{
  options.freutigo.hardware.nvidia.openKernelModule = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Use NVIDIA's open kernel module (Turing+). Disable for Maxwell/Pascal.";
  };

  config = lib.mkIf (config.freutigo.hardware.gpuProfile == "nvidia-modern") {
    freutigo.allowedUnfreePackages = [
      "nvidia-x11"
      "nvidia-kernel-modules"
      "nvidia-settings"
      "nvidia-persistenced"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      open = cfg.openKernelModule;
      modesetting.enable = true;
      nvidiaSettings = true;
    };

    boot.blacklistedKernelModules = [ "nouveau" ];
  };
}
