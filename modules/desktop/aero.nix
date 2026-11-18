# Aero Mode — the default visual profile (section 6.4).
#
# F0 status: profile skeleton. The glass theme, taskbar, launcher, window
# decoration and login screen are F2 deliverables (desktop/ directory).
# Only compositor-level defaults are set here.
{ config, lib, ... }:
let
  cfg = config.freutigo.desktop;
in
lib.mkIf (cfg.enable && cfg.mode == "aero") {
  freutigo.desktop.kdeDefaults = {
    kwinrc.Plugins = {
      blurEnabled = "true";
      contrastEnabled = "true";
    };
    kdeglobals.KDE.AnimationDurationFactor = "1";
  };
}
