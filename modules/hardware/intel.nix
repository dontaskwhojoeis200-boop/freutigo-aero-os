# Intel integrated graphics (i915 / xe kernel drivers, Mesa Iris + ANV).
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.freutigo.hardware.gpuProfile == "intel") {
  services.xserver.videoDrivers = [ "modesetting" ];

  # VA-API video decode: intel-media-driver for Broadwell (Gen8) and newer,
  # intel-vaapi-driver for older generations such as Ivy Bridge HD 2500
  # (the Pentium G2020's iGPU).
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    intel-vaapi-driver
  ];
}
