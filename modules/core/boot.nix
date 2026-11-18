{ config, lib, ... }:
let
  cfg = config.freutigo.boot;
in
{
  options.freutigo.boot = {
    mode = lib.mkOption {
      type = lib.types.enum [
        "uefi"
        "bios"
        "none"
      ];
      default = "uefi";
      description = ''
        Firmware type of the installed machine.
        - uefi: systemd-boot on the EFI system partition.
        - bios: GRUB installed to the MBR of `freutigo.boot.biosDevice`.
        - none: bootloader handled elsewhere (live ISO, VM test harness).
      '';
    };

    biosDevice = lib.mkOption {
      type = lib.types.str;
      default = "nodev";
      example = "/dev/disk/by-id/ata-WDC_WD5000AAKX-XXXXXXX";
      description = "Whole-disk device GRUB is installed to when mode = \"bios\".";
    };

    generationsInMenu = lib.mkOption {
      type = lib.types.ints.between 5 100;
      default = 20;
      description = ''
        Number of system generations listed in the boot menu. This only limits
        menu entries; it never deletes generations. Kept generously high so a
        last-known-good system is always selectable for recovery.
      '';
    };
  };

  options.freutigo.boot.recoveryEntry = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Add a "text-console" boot entry for every generation. It boots the same
      system to multi-user.target (no graphical session), giving a recovery
      path when the desktop or graphics driver is broken.
    '';
  };

  config = lib.mkMerge [
    {
      # Visible menu so older generations can be chosen (recovery path).
      boot.loader.timeout = lib.mkDefault 5;
    }

    (lib.mkIf (cfg.mode != "none" && cfg.recoveryEntry) {
      specialisation.text-console.configuration = {
        system.nixos.tags = [ "text-console" ];
        boot.kernelParams = [ "systemd.unit=multi-user.target" ];
      };
    })

    (lib.mkIf (cfg.mode == "none") {
      # NixOS enables GRUB by default; the ISO / VM modules supply their own.
      boot.loader.grub.enable = lib.mkDefault false;
    })

    (lib.mkIf (cfg.mode == "uefi") {
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = cfg.generationsInMenu;
        # Prevent editing the kernel command line from the menu without
        # physical-console intent being explicit (security). Recovery uses
        # generation selection instead; see docs/RECOVERY.md.
        editor = false;
      };
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
    })

    (lib.mkIf (cfg.mode == "bios") {
      boot.loader.grub = {
        enable = true;
        device = cfg.biosDevice;
        configurationLimit = cfg.generationsInMenu;
      };
      assertions = [
        {
          assertion = cfg.biosDevice != "nodev";
          message = "freutigo.boot.mode = \"bios\" requires freutigo.boot.biosDevice to be set to a whole disk.";
        }
      ];
    })
  ];
}
