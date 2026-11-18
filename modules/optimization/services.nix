# F5 candidate optimisations — background services.
#
# Every option here defaults to OFF. An option may only be switched on by
# default after benchmarks/ shows a measurable benefit against the F4
# baseline with no loss of required functionality (Rule 9).
{ config, lib, ... }:
let
  cfg = config.freutigo.optimization.services;
in
{
  options.freutigo.optimization.services = {
    disableModemManager = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Candidate: NetworkManager enables ModemManager by default. Desktops
        without cellular modems do not need it. Disabling breaks USB 3G/4G
        modems. Pending measurement of its idle PSS.
      '';
    };

    bluetoothOffAtBoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Candidate: keep the Bluetooth adapter powered off until the user turns it on.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.disableModemManager {
      networking.modemmanager.enable = false;
    })
    (lib.mkIf cfg.bluetoothOffAtBoot {
      hardware.bluetooth.powerOnBoot = false;
    })
  ];
}
