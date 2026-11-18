# Shared settings for every installed desktop host.
{ lib, ... }:
{
  freutigo.desktop.enable = true;
  freutigo.desktop.mode = lib.mkDefault "aero";
  freutigo.gaming.steam.enable = lib.mkDefault true;
  freutigo.development.enable = lib.mkDefault true;
  freutigo.boot.mode = lib.mkDefault "uefi";
}
