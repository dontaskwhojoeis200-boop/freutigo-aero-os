# F5 candidate optimisations — memory. All OFF until measured (Rule 9).
{ config, lib, ... }:
let
  cfg = config.freutigo.optimization.memory;
in
{
  options.freutigo.optimization.memory = {
    zram = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Candidate: compressed RAM swap (zram, zstd). Usually helps 8 GB
        systems under gaming + browser load and avoids swapping to a slow
        HDD, at a small CPU cost on the dual-core reference CPU.
        Needs benchmarking on the G2020 before becoming default.
      '';
    };

    zramPercent = lib.mkOption {
      type = lib.types.ints.between 10 100;
      default = 50;
      description = "Maximum zram device size as a percentage of RAM.";
    };
  };

  config = lib.mkIf cfg.zram {
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = cfg.zramPercent;
    };
  };
}
