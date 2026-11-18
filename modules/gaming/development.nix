# C++/Vulkan development support on the installed system (section 9.4,
# Path B). The full toolchain lives in the reproducible dev shell
# `nix develop .#cat-arena`; this module only makes per-project shells
# convenient (direnv + nix-direnv, `use flake`).
{ config, lib, ... }:
let
  cfg = config.freutigo.development;
in
{
  options.freutigo.development.enable = lib.mkEnableOption "developer conveniences (direnv with nix-direnv)";

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
