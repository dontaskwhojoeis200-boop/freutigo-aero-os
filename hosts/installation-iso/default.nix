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
  freutigoPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
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

    # Kernel and boot messages also on the first serial port (headless
    # servers, remote debugging, CI). tty0 stays the primary console.
    boot.kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty0"
    ];

    # Freutigo installs to ext4; drop ZFS (an out-of-tree kernel module that
    # can lag behind kernel updates) from the installer.
    boot.supportedFilesystems.zfs = lib.mkForce false;
    isoImage.makeUsbBootable = true;

    # The complete Freutigo source tree, so an installation can be performed
    # from the flake in the ISO (`nixos-install --flake /etc/freutigo/source#…`).
    environment.etc."freutigo/source".source = self.outPath;

    environment.systemPackages = [
      pkgs.git
      freutigoPkgs.freutigo-gpu-diagnostics
      freutigoPkgs.freutigo-detect-gpu
      freutigoPkgs.freutigo-install
    ];

    services.getty.helpLine = lib.mkForce ''

      ┌─ Freutigo Aero OS ${config.freutigo.version} installer ─────────────────────────┐
      │ Install:          sudo freutigo-install                     │
      │ Wi-Fi / network:  nmtui                                     │
      │ Check graphics:   freutigo-detect-gpu                       │
      │ Manual install:   /etc/freutigo/source/docs/INSTALL.md      │
      └─────────────────────────────────────────────────────────────┘
    '';

    # Unattended installation: only when a disk labelled AERO_AUTO with
    # an answers.env file is attached. The answers file must itself name the
    # disk to erase (CONFIRM_ERASE), so this cannot erase anything by accident.
    systemd.services.freutigo-autoinstall = {
      description = "Freutigo unattended installation (AERO_AUTO disk)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "systemd-udev-settle.service"
      ];
      wants = [ "network-online.target" ];
      path = [
        "/run/current-system/sw"
        freutigoPkgs.freutigo-install
      ];
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
      };
      script = ''
        set -o pipefail
        for _ in $(seq 1 10); do
          [ -e /dev/disk/by-label/AERO_AUTO ] && break
          sleep 1
        done
        [ -e /dev/disk/by-label/AERO_AUTO ] || exit 0
        mkdir -p /run/freutigo-auto
        mount -o ro /dev/disk/by-label/AERO_AUTO /run/freutigo-auto
        cp /run/freutigo-auto/answers.env /run/freutigo-answers.env
        umount /run/freutigo-auto
        echo "FREUTIGO-AUTOINSTALL start" > /dev/ttyS0 || true
        if freutigo-install --answers /run/freutigo-answers.env 2>&1 | tee /dev/ttyS0; then
          echo "FREUTIGO-AUTOINSTALL success" > /dev/ttyS0 || true
        else
          echo "FREUTIGO-AUTOINSTALL failed" > /dev/ttyS0 || true
          tail -n 80 /tmp/freutigo-install.log > /dev/ttyS0 || true
          systemctl poweroff
        fi
      '';
    };

    # Ship the pinned nixpkgs source so installing from the flake needs no
    # GitHub download (binary packages still come from cache.nixos.org).
    system.extraDependencies = [ self.inputs.nixpkgs.outPath ];

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
