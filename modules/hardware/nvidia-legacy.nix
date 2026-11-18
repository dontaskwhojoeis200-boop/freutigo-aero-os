# NVIDIA Kepler proprietary legacy profile — EXPERIMENTAL, OPTIONAL.
# Driver: NVIDIA 470.xx legacy branch (last branch supporting Kepler).
#
# Security / maintenance implications (section 5.3):
#  - NVIDIA ended mainstream support for the 470 branch; nixpkgs keeps it
#    building against new kernels with community (AUR-derived) patches
#    (NixOS 26.05 carries patches up to Linux 7.0). A future kernel update can
#    break the build; if so pin an older LTS kernel via freutigo.kernel.packages.
#  - Closed-source kernel module: no upstream security review.
#  - 470 has no GBM support, so KWin's Wayland session does not work.
#    This profile requires the X11 Plasma session.
#  - nixpkgs requires explicit acceptance of NVIDIA's license for legacy
#    branches; that decision is left to the machine owner.
{ config, lib, ... }:
let
  enabled = config.freutigo.hardware.gpuProfile == "nvidia-legacy-470";
  accepted = config.freutigo.hardware.nvidia.acceptLegacyLicense;
in
{
  options.freutigo.hardware.nvidia.acceptLegacyLicense = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Set to true to accept the "License For Customer Use of NVIDIA Software"
      (https://www.nvidia.com/content/DriverDownloads/licence.php?lang=us),
      which nixpkgs requires for NVIDIA legacy driver branches. This is a
      decision for the machine owner; Freutigo never accepts it by default.
    '';
  };

  config = lib.mkIf enabled {
    nixpkgs.config.nvidia.acceptLicense = accepted;

    freutigo.allowedUnfreePackages = [
      "nvidia-x11"
      "nvidia-kernel-modules"
      "nvidia-settings"
      "nvidia-persistenced"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
      # Kepler is not supported by NVIDIA's open kernel modules.
      open = false;
      modesetting.enable = true;
      nvidiaSettings = true;
      powerManagement.enable = false;
    };

    # Keep the open driver from binding the card.
    boot.blacklistedKernelModules = [ "nouveau" ];

    freutigo.desktop.session = lib.mkDefault "x11";

    assertions = [
      {
        assertion = accepted;
        message = ''
          The nvidia-legacy-470 profile requires accepting NVIDIA's driver
          license. Read it, then set freutigo.hardware.nvidia.acceptLegacyLicense = true
          in your host configuration (see docs/HARDWARE.md).
        '';
      }
      {
        assertion = !config.freutigo.desktop.enable || config.freutigo.desktop.session == "x11";
        message = "nvidia-legacy-470 has no GBM/Wayland support; set freutigo.desktop.session = \"x11\".";
      }
    ];
  };
}
