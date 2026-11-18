# PLACEHOLDER hardware configuration.
#
# Lets the desktop hosts evaluate and build in CI before a real machine
# exists. During installation this file is NOT used: the installer generates
# a real hardware-configuration.nix with `nixos-generate-config` and the host
# imports that instead (see docs/INSTALL.md).
#
# Partitions are referenced by filesystem label so the documented manual
# partitioning procedure (labels FREUTIGO_ROOT / FREUTIGO_EFI) works without
# editing UUIDs.
{ lib, ... }:
{
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/FREUTIGO_ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/FREUTIGO_EFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # SATA/AHCI + USB storage for the reference platform (Intel 7-series).
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "ehci_pci"
    "usb_storage"
    "sd_mod"
    "sr_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];
}
