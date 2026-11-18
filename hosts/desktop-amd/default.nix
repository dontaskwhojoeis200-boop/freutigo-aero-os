# Reference desktop with AMD GCN 1.0 graphics (Radeon R9 270 / HD 7850).
# Primary development target.
{ ... }:
{
  imports = [
    ../common/desktop.nix
    # Replaced by the generated file on a real installation.
    (
      if builtins.pathExists ./hardware-configuration.nix then
        ./hardware-configuration.nix
      else
        ../common/placeholder-hardware.nix
    )
  ];

  networking.hostName = "freutigo-amd";
  freutigo.hardware.gpuProfile = "amd-gcn-legacy";
}
