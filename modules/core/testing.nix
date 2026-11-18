# Hooks for automated end-to-end testing. Off by default; never enabled on a
# normal installation (only when the installer's answers file sets
# E2E_SERIAL_MARKER=yes, as scripts/e2e-install-test.sh does).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.freutigo.testing;
in
{
  options.freutigo.testing.serialBootMarker = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      After the system reaches its default target, write a boot report and
      the line FREUTIGO-BOOT-OK to the first serial port, then power off.
      Lets a headless QEMU harness verify that an installed disk boots.
    '';
  };

  config = lib.mkIf cfg.serialBootMarker {
    systemd.services.freutigo-serial-boot-marker = {
      description = "Freutigo end-to-end test: report successful boot on ttyS0";
      wantedBy = [ "multi-user.target" ];
      after = [
        "multi-user.target"
        "network-online.target"
      ]
      ++ lib.optional config.freutigo.desktop.enable "display-manager.service";
      wants = [ "network-online.target" ];
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.coreutils
        pkgs.systemd
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
      ];
      script = ''
        # Give late services a moment, then report.
        sleep 20
        {
          echo "FREUTIGO-REPORT os=$(grep ^PRETTY_NAME= /etc/os-release)"
          echo "FREUTIGO-REPORT version=$(cat /etc/freutigo/version)"
          echo "FREUTIGO-REPORT gpu-profile=$(cat /etc/freutigo/gpu-profile)"
          echo "FREUTIGO-REPORT failed-units=$(systemctl --failed --no-legend --plain | wc -l)"
          systemctl --failed --no-legend --plain | sed 's/^/FREUTIGO-REPORT failed: /'
          for u in NetworkManager systemd-resolved systemd-timesyncd display-manager; do
            echo "FREUTIGO-REPORT unit $u=$(systemctl is-active $u 2>/dev/null || true)"
          done
          echo "FREUTIGO-REPORT boot-time=$(systemd-analyze time 2>/dev/null | head -1)"
          echo "FREUTIGO-REPORT mem-used-mib=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print int((t-a)/1024)}' /proc/meminfo)"
          echo "FREUTIGO-BOOT-OK"
        } > /dev/ttyS0 2>&1 || true
        sleep 2
        systemctl poweroff --no-block
      '';
    };
  };
}
