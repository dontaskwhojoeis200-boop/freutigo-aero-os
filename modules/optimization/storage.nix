# F5 candidate optimisations — storage I/O. All OFF until measured (Rule 9).
{ config, lib, ... }:
let
  cfg = config.freutigo.optimization.storage;
in
{
  options.freutigo.optimization.storage = {
    noatimeRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Candidate: mount / with noatime instead of the kernel default
        relatime, removing access-time metadata writes on the HDD.
        Safe for almost all software; pending measurement.
      '';
    };
  };

  config = lib.mkIf cfg.noatimeRoot {
    fileSystems."/".options = [ "noatime" ];
  };
}
