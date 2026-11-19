# Freutigo Aero OS

A lightweight, Windows 7 Aero / Frutiger Aero–inspired desktop operating
system built on **NixOS 26.05 (Stable)** for everyday computing and gaming on
older x86-64 hardware (reference: Pentium G2020, 8 GB DDR3, 5400 RPM HDD,
GTX 660 / R9 270 / HD 7850 / R7 250).

> **Status: F1 — Minimal Bootable OS (complete, VM-verified).**
> The installer ISO is built in CI, installs unattended on UEFI and BIOS,
> and the installed system (console and Plasma desktop) boots in QEMU with
> no failed services. **Not yet tested on real hardware.** See
> [docs/DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md) for exact evidence.
>
> Download: GitHub Releases (`f1` pre-release) or the `freutigo-iso` CI artifact.

## Quick start (Linux with Nix + flakes)

```sh
scripts/check.sh                 # evaluate every host, GPU profile and the ISO
scripts/check.sh --full          # + lint + QEMU boot test (needs KVM + cache)
scripts/test-vm.sh               # build & run the desktop VM (freutigo/freutigo)
scripts/build-iso.sh             # build the installer ISO into dist/
sudo freutigo-install            # (on the ISO) guided installation
nix develop .#cat-arena          # C++20/Vulkan/SDL3 shell for a Linux game port
```

## Layout

| Path | Purpose |
|---|---|
| `flake.nix`, `flake.lock` | Entry point; nixpkgs pinned to `nixos-26.05` @ `f68407657ad2…` |
| `lib/` | GPU profile registry, CPU baseline, KDE INI helper |
| `modules/core/` | Boot, kernel, services, networking, audio, security, storage, users |
| `modules/hardware/` | One isolated module per GPU profile |
| `modules/desktop/` | Plasma foundation, Aero / Aero Lite profiles, themes |
| `modules/gaming/` | Steam/Proton, Vulkan tools, developer conveniences |
| `modules/optimization/` | F5 candidates — all **off** until benchmarked |
| `hosts/` | `desktop-amd`, `desktop-nvidia`, `desktop-nvidia-legacy`, `virtual-machine`, `installation-iso` |
| `packages/` | `freutigo-gpu-diagnostics`, `freutigo-benchmark`, dev shells |
| `scripts/` | check, build-iso, test-vm, diagnostics, benchmark |
| `tests/` | NixOS VM tests |
| `desktop/` | Original Aero shell components and assets (F2+) |
| `docs/` | Architecture, build, install, hardware, performance, compatibility, recovery, log |

## Principles

Stability before RAM savings · reproducible from the lockfile · never claim
untested results · reuse proven Linux components · AMD and NVIDIA profiles
isolated · security features stay on · optimise only from measurements.

## Licence

Not yet chosen; this decision belongs to the project owner. All artwork must be
original; no Microsoft-owned themes, icons, wallpapers, sounds, fonts or
binaries.
