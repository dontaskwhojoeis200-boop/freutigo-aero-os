# KDE Plasma 6 as the initial desktop foundation (section 7.2). Plasma is an
# evaluation baseline, not a permanent commitment; F5 measures it against the
# sub-1-GiB idle target.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.freutigo.desktop;
in
{
  options.freutigo.desktop.fileIndexing = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable Baloo file content indexing. Off by default: on the 5400 RPM
      reference HDD, background indexing causes sustained disk I/O
      (section IV, "reduce unnecessary disk activity and background indexing").
      Dolphin filename search works without it.
    '';
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;

    # The X11 session (legacy fallback) needs the X server and an X11 SDDM
    # greeter. Under Wayland, KWin provides Xwayland for X11 applications.
    services.xserver.enable = cfg.session == "x11";

    services.displayManager = {
      sddm = {
        enable = true;
        # Run the greeter itself on Wayland when the session is Wayland.
        wayland.enable = cfg.session == "wayland";
      };
      defaultSession = if cfg.session == "wayland" then "plasma" else "plasmax11";
    };

    # Trim applications that are not part of the everyday-desktop scope or
    # duplicate other choices. Everything here is installable later.
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa # music player (pulls Baloo-based library scanning)
      khelpcenter
    ];

    # Default applications (section 8). Firefox is the default browser.
    programs.firefox.enable = true;

    environment.systemPackages = with pkgs; [
      kdePackages.kcalc
      kdePackages.spectacle # screenshots
      kdePackages.partitionmanager
      kdePackages.filelight # storage usage
      vlc # video playback (broad codec support)
    ];

    freutigo.desktop.kdeDefaults.baloofilerc."Basic Settings"."Indexing-Enabled" =
      lib.boolToString cfg.fileIndexing;

    # XDG portals for Flatpak/Steam file dialogs.
    xdg.portal.enable = true;
  };
}
