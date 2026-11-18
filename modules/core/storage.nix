{ pkgs, ... }:
{
  # Filesystems users plug in (section 8.3). ntfs uses the in-kernel ntfs3
  # driver; ntfs-3g is kept for repair tools.
  boot.supportedFilesystems = {
    ntfs = true;
    exfat = true;
    vfat = true;
    ext4 = true;
  };

  # Automounting / removable media for the file manager.
  services.udisks2.enable = true;
  services.gvfs.enable = false; # KDE uses KIO; gvfs only adds idle processes.

  # Periodic TRIM for SSDs. On HDDs fstrim skips devices without discard
  # support, so this is harmless on the 5400 RPM reference disk.
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    ntfs3g
    exfatprogs
    dosfstools
    e2fsprogs
    # Archives (Ark in the desktop uses these back ends)
    unzip
    zip
    p7zip
  ];
}
