# Reference desktop with NVIDIA GeForce GTX 660 — proprietary 470 driver.
# EXPERIMENTAL / OPTIONAL. X11 session only. See docs/HARDWARE.md.
{ ... }:
{
  imports = [
    ../common/desktop.nix
    (if builtins.pathExists ./hardware-configuration.nix then
      ./hardware-configuration.nix
    else
      ../common/placeholder-hardware.nix)
  ];

  networking.hostName = "freutigo-nvidia-legacy";
  freutigo.hardware.gpuProfile = "nvidia-legacy-470";
  freutigo.desktop.session = "x11";

  # Owner decision: read NVIDIA's license, then set this to true.
  # https://www.nvidia.com/content/DriverDownloads/licence.php?lang=us
  freutigo.hardware.nvidia.acceptLegacyLicense = false;
}
