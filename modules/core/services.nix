{ lib, ... }:
{
  # Essential system services (section 3.3). Everything listed here is
  # required for an everyday desktop; optional trimming lives in
  # modules/optimization/ and is off until measured.

  # Time synchronisation (systemd-timesyncd, NixOS default).
  services.timesyncd.enable = lib.mkDefault true;

  # Bounded journal: protects small/slow disks from unbounded log growth.
  # This is a disk-usage cap, not a speed optimisation.
  services.journald.extraConfig = ''
    SystemMaxUse=256M
    RuntimeMaxUse=64M
  '';

  # Power management for desktops (CPU frequency scaling is kernel default;
  # power-profiles-daemon/upower come with the desktop module).
  powerManagement.enable = true;

  # Firmware updates are handled out-of-band; fwupd is dbus-activated so it
  # costs no idle memory but allows UEFI/peripheral updates where supported.
  services.fwupd.enable = lib.mkDefault true;

  # Hardware detection / device permissions: udev and logind are always on
  # in NixOS; nothing to configure here.
}
