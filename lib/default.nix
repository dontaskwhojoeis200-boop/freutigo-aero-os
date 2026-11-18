{ lib }:
rec {
  # Canonical list of GPU profiles. Each maps to exactly one module under
  # modules/hardware/. "status" follows the verification ladder in
  # docs/DEVELOPMENT_LOG.md and must only be raised after real testing.
  gpuProfileInfo = {
    amd-gcn-legacy = {
      description = "AMD GCN 1.0/1.1 (Radeon HD 7000, R7/R9 200) — amdgpu + RADV";
      module = "amd-gcn.nix";
      status = "evaluated";
      experimental = false;
    };
    nvidia-kepler-oss = {
      description = "NVIDIA Kepler (GTX 600/700) — nouveau + NVK (open source)";
      module = "nvidia-kepler.nix";
      status = "evaluated";
      experimental = false;
    };
    nvidia-legacy-470 = {
      description = "NVIDIA Kepler — proprietary 470.xx legacy driver (EXPERIMENTAL, X11 only)";
      module = "nvidia-legacy.nix";
      status = "evaluated";
      experimental = true;
    };
    amd-modern = {
      description = "AMD GCN 3+ / RDNA — amdgpu + RADV";
      module = "amd-modern.nix";
      status = "evaluated";
      experimental = false;
    };
    nvidia-modern = {
      description = "NVIDIA Turing or newer — current proprietary driver, open kernel module";
      module = "nvidia-modern.nix";
      status = "evaluated";
      experimental = false;
    };
    intel = {
      description = "Intel integrated graphics — i915/xe + Mesa (ANV/Iris)";
      module = "intel.nix";
      status = "evaluated";
      experimental = false;
    };
    virtual-machine = {
      description = "QEMU/KVM guest — virtio-gpu, SPICE agent";
      module = "virtual.nix";
      status = "evaluated";
      experimental = false;
    };
  };

  gpuProfiles = builtins.attrNames gpuProfileInfo;

  # x86-64 micro-architecture levels the Pentium G2020 (Ivy Bridge, no AVX)
  # can execute. x86-64-v3 and above require AVX/AVX2 and are forbidden.
  compatibleMarchLevels = [
    "x86-64"
    "x86-64-v2"
  ];

  # Render a { file = { group = { key = value; }; }; } attrset into
  # environment.etc entries under /etc/xdg (KDE system-wide defaults).
  mkXdgIniFiles =
    files:
    lib.mapAttrs' (
      file: groups: lib.nameValuePair "xdg/${file}" { text = lib.generators.toINI { } groups; }
    ) files;
}
