# Freutigo Aero OS installation ISO.
#
# F0/F1: based on the proven NixOS minimal installer (text mode) with
# Freutigo branding, the Freutigo source tree, and diagnostic tools. The
# graphical, branded installer is an F6 deliverable (section 11.1 allows a
# proven NixOS workflow if a custom graphical installer is unreliable).
{
  config,
  lib,
  pkgs,
  modulesPath,
  self,
  ...
}:
let
  cfg = config.freutigo.iso;
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  options.freutigo.iso.includeTargetClosure = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "desktop-amd";
    description = ''
      Name of a nixosConfiguration whose complete system closure is copied
      into the ISO, enabling installation without internet access
      (section 11.3). Makes the ISO several GB larger. Hosts that enable
      Steam cannot be embedded (Steam may not be redistributed).
    '';
  };

  config = {
    freutigo.boot.mode = "none"; # the ISO module provides its own bootloader
    freutigo.user.enable = false; # the installer uses the `nixos` live user
    freutigo.hardware.gpuProfile = "none";
    freutigo.desktop.enable = false;

    networking.hostName = lib.mkForce "freutigo-installer";

    # installation-cd-base gives the live `root` and `nixos` users empty
    # passwords; let it, instead of the locked root of installed systems.
    users.users.root.hashedPassword = lib.mkForce null;

    # Upstream installer behaviour for remote installs: sshd is NOT started
    # by default; if the user starts it they must first set a root password
    # (empty passwords are refused by sshd). Installed systems keep "no".
    services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

    image.baseName = lib.mkForce "freutigo-aero-os-${config.freutigo.version}-x86_64";
    isoImage.volumeID = lib.mkForce "FREUTIGO_AERO_OS";
    isoImage.appendToMenuLabel = " Freutigo Aero OS installer";

    # Both firmware types (section 11.1). Explicit even though the minimal
    # installer already enables them.
    isoImage.makeEfiBootable = true;

    # Freutigo installs to ext4; drop ZFS (an out-of-tree kernel module that
    # can lag behind kernel updates) from the installer.
    boot.supportedFilesystems.zfs = lib.mkForce false;
    isoImage.makeUsbBootable = true;

    # The complete Freutigo source tree, so an installation can be performed
    # from the flake in the ISO (`nixos-install --flake /etc/freutigo/source#…`).
    environment.etc."freutigo/source".source = self.outPath;

    environment.systemPackages = [
      pkgs.git
      self.packages.${pkgs.stdenv.hostPlatform.system}.freutigo-gpu-diagnostics
    ];

    isoImage.storeContents = lib.optional (cfg.includeTargetClosure != null)
      self.nixosConfigurations.${cfg.includeTargetClosure}.config.system.build.toplevel;

    assertions = [
      {
        assertion = !config.freutigo.gaming.steam.enable;
        message = "The installation ISO must not contain Steam (redistribution, section 9.1).";
      }
      {
        assertion =
          cfg.includeTargetClosure == null
          || !self.nixosConfigurations.${cfg.includeTargetClosure}.config.freutigo.gaming.steam.enable;
        message = "freutigo.iso.includeTargetClosure: the target host enables Steam, which may not be redistributed in the ISO. Disable Steam for an offline image.";
      }
    ];
  };
}
