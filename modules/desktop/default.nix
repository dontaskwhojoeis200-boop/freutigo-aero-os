{
  config,
  lib,
  freutigoLib,
  ...
}:
let
  cfg = config.freutigo.desktop;
in
{
  imports = [
    ./plasma.nix
    ./aero.nix
    ./aero-lite.nix
    ./themes.nix
  ];

  options.freutigo.desktop = {
    enable = lib.mkEnableOption "the Freutigo Aero graphical desktop";

    mode = lib.mkOption {
      type = lib.types.enum [
        "aero"
        "aero-lite"
      ];
      default = "aero";
      description = ''
        Visual profile (section 6.4).
        - aero: full glass/blur/animation experience (default).
        - aero-lite: same visual identity with reduced compositor workload.
      '';
    };

    session = lib.mkOption {
      type = lib.types.enum [
        "wayland"
        "x11"
      ];
      default = "wayland";
      description = ''
        Default display protocol for the Plasma session. Wayland is preferred;
        X11 remains available as a fallback for legacy drivers (NixOS 26.05 /
        Plasma 6.6 still ship kwin-x11).
      '';
    };

    kdeDefaults = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.attrsOf lib.types.str));
      default = { };
      example = {
        kdeglobals.KDE.AnimationDurationFactor = "0.5";
      };
      description = ''
        System-wide KDE defaults written to /etc/xdg/<file> as INI
        (file -> group -> key -> value). Users' own settings in ~/.config
        override these, so they act as distribution defaults only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc = freutigoLib.mkXdgIniFiles cfg.kdeDefaults // {
      "freutigo/desktop-mode".text = cfg.mode + "\n";
    };
  };
}
