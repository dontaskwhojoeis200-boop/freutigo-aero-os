{ config, lib, ... }:
let
  cfg = config.freutigo.user;
in
{
  options.freutigo.user = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the primary desktop user account.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "freutigo";
      description = "Login name of the primary user (set by the installer).";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "Freutigo User";
      description = "Display name shown on the login screen.";
    };

    initialPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Development/VM only. Plain-text initial password stored in the Nix
        store. Real installations leave this null and set the password during
        installation with `passwd` (see docs/INSTALL.md).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Passwords are managed imperatively with passwd (not in the store).
    users.mutableUsers = true;

    users.users.${cfg.name} = {
      isNormalUser = true;
      inherit (cfg) description;
      extraGroups = [
        "wheel" # administration via sudo (password required)
        "networkmanager"
        "video"
        "audio"
        "input" # game controllers
      ];
      initialPassword = lib.mkIf (cfg.initialPassword != null) cfg.initialPassword;
    };

    warnings = lib.optional (cfg.initialPassword != null) ''
      freutigo.user.initialPassword is set; it is world-readable in the Nix
      store. Only use this for development VMs.
    '';
  };
}
