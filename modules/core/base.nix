{
  config,
  lib,
  pkgs,
  freutigoLib,
  ...
}:
let
  cfg = config.freutigo;
  march = config.nixpkgs.hostPlatform.gcc.arch or null;
in
{
  options.freutigo = {
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.1.0-f1";
      description = "Freutigo Aero OS version string (development phase suffix until 1.0).";
    };

    allowedUnfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Unfree package names permitted on this system. Modules append to this
        list only when the corresponding feature is enabled, so the default
        system contains no unfree software.
      '';
    };
  };

  config = {
    # ---- Branding (os-release, boot menu entries) -------------------------
    system.nixos.distroName = "Freutigo Aero OS";
    system.nixos.distroId = "freutigo";
    system.nixos.vendorName = "Freutigo";
    system.nixos.vendorId = "freutigo";

    environment.etc."freutigo/version".text = cfg.version + "\n";

    # ---- Nix ----------------------------------------------------------------
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Keep signature verification on (secure package-source verification).
      require-sigs = true;
      auto-optimise-store = true;
    };

    # Explicit, narrow unfree allowlist instead of allowUnfree = true.
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) cfg.allowedUnfreePackages;

    # ---- Locale defaults (installer / host may override) -------------------
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    console.keyMap = lib.mkDefault "us";
    time.timeZone = lib.mkDefault "UTC";

    environment.systemPackages = with pkgs; [
      git # required to work with the system flake
      pciutils
      usbutils
      file
      htop
    ];

    # ---- CPU baseline ---------------------------------------------------------
    # The reference CPU (Pentium G2020) lacks AVX. Never compile the system for
    # a micro-architecture level that requires it.
    assertions = [
      {
        assertion = march == null || builtins.elem march freutigoLib.compatibleMarchLevels;
        message = ''
          Freutigo Aero OS: nixpkgs.hostPlatform.gcc.arch = "${toString march}" is not
          allowed. The reference CPU (Intel Pentium G2020) has no AVX/AVX2.
          Permitted values: ${lib.concatStringsSep ", " freutigoLib.compatibleMarchLevels} (or unset).
        '';
      }
    ];

    # First release this configuration was written against. Do not change on
    # an installed system; see NixOS manual "system.stateVersion".
    system.stateVersion = "26.05";
  };
}
