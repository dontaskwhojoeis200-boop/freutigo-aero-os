# Aero Lite Mode — same visual identity, lower compositor workload
# (section 6.4). Blur is the most expensive KWin effect on GCN 1.0 / Kepler
# class GPUs; it is disabled and animations are shortened.
#
# F0 status: profile skeleton. F2 adds the opaque/low-alpha variants of the
# Aero theme assets so Lite Mode does not look unfinished. F5 measures the
# actual GPU/CPU difference between the modes.
{ config, lib, ... }:
let
  cfg = config.freutigo.desktop;
in
lib.mkIf (cfg.enable && cfg.mode == "aero-lite") {
  freutigo.desktop.kdeDefaults = {
    kwinrc.Plugins = {
      blurEnabled = "false";
      contrastEnabled = "false";
    };
    kdeglobals.KDE.AnimationDurationFactor = "0.5";
  };
}
