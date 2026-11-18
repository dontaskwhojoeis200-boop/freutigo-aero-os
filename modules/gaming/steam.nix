# Steam + Proton (section IX). F4 deliverable; defined now so profiles can be
# evaluated together with gaming support.
#
# Redistribution: Steam is unfree. The nixpkgs `steam` package is a bootstrap
# wrapper that downloads Valve's client on first launch. It is built on the
# user's machine at install/rebuild time and is NEVER placed in the
# installation ISO (asserted in hosts/installation-iso).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.freutigo.gaming.steam;
in
{
  options.freutigo.gaming.steam = {
    enable = lib.mkEnableOption "Steam with Steam Play (Proton)";

    remotePlay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for Steam Remote Play (off by default).";
    };

    extraCompatTools = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install Proton-GE as an additional selectable compatibility tool.
        Valve's own Proton versions remain selectable inside Steam.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    freutigo.allowedUnfreePackages = [
      "steam"
      "steam-unwrapped"
      "steam-original"
      "steam-run"
    ];

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = cfg.remotePlay;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = false;
      extraCompatPackages = lib.optionals cfg.extraCompatTools [ pkgs.proton-ge-bin ];
    };

    # Feral GameMode: raises CPU governor / scheduling priority only while
    # a game requests it. Meaningful on the dual-core Pentium G2020.
    programs.gamemode.enable = true;

    # Controllers: Steam's udev rules (Steam Controller, DualShock, etc.).
    hardware.steam-hardware.enable = true;

    assertions = [
      {
        assertion = config.hardware.graphics.enable32Bit;
        message = "Steam requires 32-bit graphics libraries (hardware.graphics.enable32Bit).";
      }
    ];
  };
}
