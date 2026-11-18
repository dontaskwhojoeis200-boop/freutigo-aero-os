{ config, lib, ... }:
let
  autoLogin = config.services.displayManager.autoLogin;
in
{
  # Normal authentication: wheel members must enter their password for sudo.
  security.sudo.wheelNeedsPassword = true;
  security.polkit.enable = true;

  # Root has no password by default on NixOS (cannot log in); keep it that way.
  users.users.root.hashedPassword = lib.mkDefault "!";

  # Remote access is off unless a host opts in; if it does, no root login.
  services.openssh.settings.PermitRootLogin = lib.mkDefault "no";

  assertions = [
    {
      assertion = !(autoLogin.enable && autoLogin.user == "root");
      message = "Freutigo Aero OS: automatic root login is forbidden (section 10.3).";
    }
    {
      assertion = config.networking.firewall.enable;
      message = "Freutigo Aero OS: the firewall must stay enabled (section 10.3).";
    }
    {
      assertion = config.nix.settings.require-sigs;
      message = "Freutigo Aero OS: Nix signature verification must stay enabled.";
    }
  ];
}
