# Reference desktop with NVIDIA GeForce GTX 660 (Kepler) — open-source stack.
{ ... }:
{
  imports = [
    ../common/desktop.nix
    (
      if builtins.pathExists ./hardware-configuration.nix then
        ./hardware-configuration.nix
      else
        ../common/placeholder-hardware.nix
    )
  ];

  networking.hostName = "freutigo-nvidia";
  freutigo.hardware.gpuProfile = "nvidia-kepler-oss";
}
