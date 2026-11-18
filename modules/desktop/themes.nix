# Freutigo Aero theme packaging (section VII).
#
# F0 status: placeholder. F2 will package the original assets from
# desktop/themes, desktop/icons, desktop/wallpapers and desktop/sounds as
# Nix derivations under packages/ and install them here.
#
# Asset rule (section 7.4): only original artwork. No Microsoft-owned themes,
# icons, wallpapers, sounds, fonts (e.g. Segoe UI) or binaries may be added.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.freutigo.desktop.enable {
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
    ];
  };
}
