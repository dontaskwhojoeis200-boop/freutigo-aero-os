{
  description = "Freutigo Aero OS — a lightweight, Aero-styled NixOS-based desktop operating system";

  inputs = {
    # NixOS Stable 26.05. The exact revision is pinned in flake.lock.
    # Do NOT switch this to nixos-unstable or a newer release branch without a
    # separate evaluation cycle (see docs/ARCHITECTURE.md, "Update policy").
    #
    # A shallow git input is used (rather than github:) because it locks to the
    # same revision + narHash and works through git-only network policies.
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&shallow=1";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.${system};

      freutigoLib = import ./lib { inherit lib; };

      # Build a Freutigo system from a list of extra modules.
      mkSystem =
        modules:
        lib.nixosSystem {
          specialArgs = { inherit self freutigoLib; };
          modules = [
            { nixpkgs.hostPlatform = system; }
            self.nixosModules.default
          ]
          ++ modules;
        };

      hosts = {
        desktop-amd = [ ./hosts/desktop-amd ];
        desktop-nvidia = [ ./hosts/desktop-nvidia ];
        desktop-nvidia-legacy = [ ./hosts/desktop-nvidia-legacy ];
        virtual-machine = [ ./hosts/virtual-machine ];
        vm-minimal = [ ./hosts/vm-minimal ];
        installation-iso = [ ./hosts/installation-iso ];
      }
      # Written by freutigo-install on an installed machine.
      // lib.optionalAttrs (builtins.pathExists ./hosts/local/default.nix) {
        local = [ ./hosts/local ];
      };

      nixosConfigurations = lib.mapAttrs (_: mkSystem) hosts;

      # Every GPU profile is evaluated on top of the VM host so that profiles
      # without a dedicated host (modern AMD/NVIDIA, Intel) are still checked.
      profileConfigurations = lib.genAttrs freutigoLib.gpuProfiles (
        profile:
        mkSystem [
          ./hosts/virtual-machine
          { freutigo.hardware.gpuProfile = lib.mkForce profile; }
        ]
      );

      # CI evaluation only: type-check the NVIDIA legacy profile, which
      # otherwise (correctly) refuses to evaluate until the machine owner
      # accepts NVIDIA's license. Nothing is built or distributed by this.
      ciEvalModule = {
        freutigo.hardware.nvidia.acceptLegacyLicense = lib.mkForce true;
      };
      forCi = cfg: cfg.extendModules { modules = [ ciEvalModule ]; };

      # Evaluation-only check: forces full evaluation of a system (including
      # all assertions) without building it. The drvPath string context is
      # discarded so the check itself does not depend on the system closure.
      evalCheck =
        name: drv:
        pkgs.writeText "freutigo-eval-${name}" (builtins.unsafeDiscardStringContext drv.drvPath);
    in
    {
      inherit nixosConfigurations;

      nixosModules.default = ./modules;

      packages.${system} = {
        freutigo-gpu-diagnostics = pkgs.callPackage ./packages/freutigo-gpu-diagnostics { };
        freutigo-benchmark = pkgs.callPackage ./packages/freutigo-benchmark { };
        freutigo-detect-gpu = pkgs.callPackage ./packages/freutigo-detect-gpu { };
        freutigo-install = pkgs.callPackage ./packages/freutigo-install {
          inherit (self.packages.${system}) freutigo-detect-gpu;
        };
        iso = nixosConfigurations.installation-iso.config.system.build.isoImage;
        vm = nixosConfigurations.virtual-machine.config.system.build.vm;
        vm-minimal = nixosConfigurations.vm-minimal.config.system.build.vm;
        default = self.packages.${system}.iso;
      };

      devShells.${system} = {
        # Operating-system development: formatting, linting, VM testing.
        default = pkgs.mkShell {
          name = "freutigo-os-dev";
          packages = with pkgs; [
            nixfmt
            statix
            deadnix
            shellcheck
            qemu_kvm
            OVMF
            git
            jq
          ];
        };

        # Native Linux port environment for Cat Arena: Feral Claw (C++20 / Vulkan / SDL3).
        cat-arena = import ./packages/dev-shells/cat-arena.nix { inherit pkgs; };
      };

      formatter.${system} = pkgs.nixfmt;

      checks.${system} =
        (lib.mapAttrs' (
          name: cfg:
          lib.nameValuePair "eval-host-${name}" (evalCheck name (forCi cfg).config.system.build.toplevel)
        ) nixosConfigurations)
        // (lib.mapAttrs' (
          name: cfg:
          lib.nameValuePair "eval-profile-${name}" (evalCheck name (forCi cfg).config.system.build.toplevel)
        ) profileConfigurations)
        // {
          eval-iso-image = evalCheck "iso" nixosConfigurations.installation-iso.config.system.build.isoImage;

          shellcheck = pkgs.runCommand "freutigo-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck --severity=warning ${./scripts}/*.sh
            touch $out
          '';

          nix-format = pkgs.runCommand "freutigo-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            find ${./.} -name '*.nix' -print0 | xargs -0 nixfmt --check
            touch $out
          '';

          # GPU auto-detection against fake sysfs fixtures (no hardware).
          gpu-detect =
            pkgs.runCommand "freutigo-gpu-detect-tests"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  gawk
                  gnugrep
                  gnused
                ];
              }
              ''
                bash ${./tests/gpu-detect/run.sh} ${./scripts/detect-gpu-profile.sh}
                touch $out
              '';

          # Boots the core system in QEMU and checks essential services.
          # Requires KVM on the build machine.
          vmtest-core = import ./tests/core-boot.nix { inherit pkgs self freutigoLib; };

          # Boots the desktop VM host to the SDDM greeter and logs in.
          vmtest-desktop = import ./tests/desktop-boot.nix { inherit pkgs self freutigoLib; };
        };
    };
}
