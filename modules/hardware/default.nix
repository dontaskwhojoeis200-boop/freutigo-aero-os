{
  config,
  lib,
  freutigoLib,
  ...
}:
let
  cfg = config.freutigo.hardware;
  info = freutigoLib.gpuProfileInfo.${cfg.gpuProfile} or null;
in
{
  # Each GPU profile lives in its own file and activates only when selected,
  # so AMD and NVIDIA configurations stay independently maintainable
  # (Rule 6: driver isolation).
  imports = [
    ./amd-gcn.nix
    ./amd-modern.nix
    ./nvidia-kepler.nix
    ./nvidia-legacy.nix
    ./nvidia-modern.nix
    ./intel.nix
    ./virtual.nix
  ];

  options.freutigo.hardware = {
    gpuProfile = lib.mkOption {
      type = lib.types.enum (freutigoLib.gpuProfiles ++ [ "none" ]);
      default = "none";
      description = ''
        Graphics driver profile. Exactly one is active per system.
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (n: v: "- ${n}: ${v.description}") freutigoLib.gpuProfileInfo
        )}
        - none: no graphics stack (headless / text-only).
      '';
    };
  };

  config = lib.mkMerge [
    {
      environment.etc."freutigo/gpu-profile".text = cfg.gpuProfile + "\n";
    }

    (lib.mkIf (cfg.gpuProfile != "none") {
      # Shared by every GPU profile: Mesa/driver userspace, plus 32-bit
      # libraries for Steam and Proton.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    (lib.mkIf (info != null && info.experimental) {
      warnings = [
        "GPU profile '${cfg.gpuProfile}' is EXPERIMENTAL and not part of the supported configuration set. See docs/HARDWARE.md."
      ];
    })

    {
      assertions = [
        {
          assertion = !(config.freutigo.desktop.enable && cfg.gpuProfile == "none");
          message = "freutigo.desktop.enable requires a freutigo.hardware.gpuProfile other than \"none\".";
        }
      ];
    }
  ];
}
