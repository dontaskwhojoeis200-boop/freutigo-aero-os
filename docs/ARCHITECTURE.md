# Architecture

## 1. Layers

```
┌──────────────────────────────────────────────────────────────┐
│ hosts/<name>        machine composition: GPU profile, mode,  │
│                     boot mode, hardware-configuration.nix    │
├──────────────────────────────────────────────────────────────┤
│ modules/desktop     Plasma 6 foundation → Aero / Aero Lite   │
│ modules/gaming      Steam + Proton, Vulkan tools, dev        │
│ modules/hardware    exactly one GPU profile active           │
│ modules/optimization F5 candidates (all off by default)      │
│ modules/core        boot, kernel, services, net, audio,      │
│                     security, storage, users                 │
├──────────────────────────────────────────────────────────────┤
│ nixpkgs nixos-26.05 @ f68407657ad294471eb4b2e65d193df26edf729f│
│ Linux 6.18 LTS · Mesa 26.1 · Plasma 6.6 · systemd · PipeWire │
└──────────────────────────────────────────────────────────────┘
```

All behaviour is selected through options in the `freutigo.*` namespace. Every
module declares its own options next to its implementation, and no module reads
another module's private state. A host file is a short list of choices:

```nix
freutigo.hardware.gpuProfile = "amd-gcn-legacy";
freutigo.desktop.enable = true;
freutigo.desktop.mode = "aero";        # or "aero-lite"
freutigo.boot.mode = "uefi";           # or "bios" (+ biosDevice)
```

## 2. Option reference (F0)

| Option | Default | Module |
|---|---|---|
| `freutigo.version` | `0.0.0-f0` | core/base |
| `freutigo.allowedUnfreePackages` | `[]` | core/base |
| `freutigo.boot.mode` | `uefi` | core/boot |
| `freutigo.boot.biosDevice` | `nodev` | core/boot |
| `freutigo.boot.generationsInMenu` | `20` | core/boot |
| `freutigo.boot.recoveryEntry` | `true` | core/boot |
| `freutigo.kernel.packages` | `pkgs.linuxPackages` (6.18 LTS) | core/kernel |
| `freutigo.user.{enable,name,description,initialPassword}` | `true`, `freutigo`, …, `null` | core/users |
| `freutigo.hardware.gpuProfile` | `none` | hardware |
| `freutigo.hardware.nvidia.openKernelModule` | `true` | hardware/nvidia-modern |
| `freutigo.hardware.nvidia.acceptLegacyLicense` | `false` | hardware/nvidia-legacy |
| `freutigo.desktop.enable` | `false` | desktop |
| `freutigo.desktop.mode` | `aero` | desktop |
| `freutigo.desktop.session` | `wayland` | desktop |
| `freutigo.desktop.kdeDefaults` | `{}` | desktop |
| `freutigo.desktop.fileIndexing` | `false` | desktop/plasma |
| `freutigo.gaming.steam.{enable,remotePlay,extraCompatTools}` | `false`, `false`, `true` | gaming/steam |
| `freutigo.development.enable` | `false` | gaming/development |
| `freutigo.optimization.*` | all `false` | optimization |
| `freutigo.iso.includeTargetClosure` | `null` | hosts/installation-iso |
| `freutigo.testing.serialBootMarker` | `false` | core/testing (E2E test hook only) |

## 2a. Hosts

| Host | Purpose |
|---|---|
| `desktop-amd`, `desktop-nvidia`, `desktop-nvidia-legacy` | Reference desktops (placeholder hardware config until installed) |
| `virtual-machine` | Desktop in QEMU for development |
| `vm-minimal` | F1 minimal system: core OS + graphics stack, no desktop |
| `installation-iso` | Installer image |
| `local` | Exists only on installed machines: written by `freutigo-install` to `/etc/freutigo/hosts/local` |

## 2b. Installer flow

```
ISO boot → freutigo-install
  network check → locale/keymap/tz → user → freutigo-detect-gpu (+override)
  → desktop/mode/Steam → firmware + disk (erase w/ typed confirmation | mounted)
  → summary ("install") → partition/format (erase only)
  → copy /etc/freutigo/source → /mnt/etc/freutigo, write hosts/local/{default,hardware-configuration}.nix
  → git commit → nixos-install --flake /mnt/etc/freutigo#local → chpasswd → reboot
```

`freutigo-detect-gpu` decides AMD generations from the kernel's own
`modules.alias` (a device claimable by both `radeon` and `amdgpu` is GCN 1.0/1.1),
NVIDIA generations from nouveau's chipset log line (device-ID heuristic as
fallback), and Intel/virtual GPUs by vendor ID.

## 3. GPU profiles (driver isolation, Rule 6)

`lib/default.nix` is the single registry of profiles. Each profile is one file
in `modules/hardware/` wrapped in `mkIf (gpuProfile == "<name>")`, so changing
one profile cannot alter another. Shared by every graphical profile:
`hardware.graphics.enable` and `enable32Bit` (Steam/Proton).

| Profile | Kernel driver | GL | Vulkan | Session |
|---|---|---|---|---|
| `amd-gcn-legacy` | amdgpu (forced via `si_support`/`cik_support`) | radeonsi | RADV | Wayland |
| `nvidia-kepler-oss` | nouveau | nouveau (nvc0) | NVK | Wayland |
| `nvidia-legacy-470` | nvidia 470.256.02 (proprietary) | NVIDIA | NVIDIA | **X11 only** |
| `amd-modern` | amdgpu | radeonsi | RADV | Wayland |
| `nvidia-modern` | nvidia (stable, open module) | NVIDIA | NVIDIA | Wayland |
| `intel` | i915 / xe | iris | ANV | Wayland |
| `virtual-machine` | virtio-gpu | virgl | — | Wayland |

## 4. Key decisions

| # | Decision | Reason |
|---|---|---|
| D1 | nixpkgs input is `git+https://…?ref=nixos-26.05&shallow=1` | Locks to the same rev + narHash as `github:`; also works where only git transport is allowed (the F0 build environment). |
| D2 | Unfree software only through `freutigo.allowedUnfreePackages` | Default system is entirely free software; each feature declares exactly what it needs. |
| D3 | Plasma 6 is the initial desktop | Section 7.2. Mature Wayland compositor with blur/contrast effects and full theming. F5 measures it against the 1 GiB idle ceiling; XFCE/LXQt/custom compositor are fallbacks. |
| D4 | Wayland default, X11 session kept | NixOS 26.05 still ships `kwin-x11` (Plasma 6.6). The 470 driver requires X11. |
| D5 | ISO based on the NixOS minimal installer | Section 11.1 permits a proven workflow; branded graphical installer is F6. ZFS removed (installs are ext4). |
| D6 | Steam never in the ISO | Section 9.1; asserted in the ISO host. |
| D7 | Optimisations exist as options, all off | Rule 9: enabled by default only after benchmarks. |
| D8 | Baloo indexing off by default | Section IV: reduce background indexing on HDDs. File-name search still works. |
| D9 | `text-console` specialisation per generation | Text recovery path without kernel-command-line editing (systemd-boot editor is disabled). |
| D10 | Root locked, sudo requires password, firewall on, Nix signatures required | Section 10.3; enforced by assertions. |
| D11 | No automatic garbage collection | Never delete the last-known-good generation automatically (section 10.1). |
| D12 | NVIDIA legacy licence acceptance is an explicit owner setting | Legal decision; CI evaluation alone forces it on (nothing built or distributed). |

## 5. Update policy

* **Package updates (same release):** `nix flake update nixpkgs` moves to the
  newest `nixos-26.05` commit. Run `scripts/check.sh`, build, boot the VM, then
  `nixos-rebuild boot` (not `switch`) on real machines; the previous generation
  stays in the boot menu.
* **Major upgrades (e.g. 26.11):** change the `ref` in `flake.nix` on a separate
  branch, run every check, record results, merge only after validation.
* **No `system.autoUpgrade`, no automatic reboots, no unstable channel.** An
  update GUI is an F6 deliverable.

## 6. Checks

`checks.x86_64-linux` contains:

* `eval-host-*`: every host's full system, all assertions included.
* `eval-profile-*`: the VM host with each GPU profile substituted, so profiles
  without a dedicated host are also checked.
* `eval-iso-image`: the ISO image derivation.
* `shellcheck`, `nix-format`: lint (needs building).
* `vmtest-core`: QEMU boot test of the core OS (needs building + KVM).
* `vmtest-desktop`: QEMU test, SDDM greeter → password login → Plasma Wayland.
* `gpu-detect`: GPU detection fixture tests.

Outside `nix flake check`: `scripts/e2e-install-test.sh` performs a real
installation from the ISO into a QEMU disk and boots it (needs network).

`scripts/check.sh` runs the evaluation checks without building anything.
