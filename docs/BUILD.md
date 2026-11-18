# Building Freutigo Aero OS

## Requirements

* Linux x86_64 (any distribution, or NixOS) with **Nix ≥ 2.18** and flakes
  enabled (`experimental-features = nix-command flakes`).
* Network access to `github.com` (nixpkgs source) and **`cache.nixos.org`**
  (prebuilt binaries). Without the binary cache, everything, including the
  kernel, Mesa, Qt and Plasma, compiles from source: many hours on a fast
  machine, impractical on the reference Pentium G2020.
* KVM (`/dev/kvm`) for `scripts/test-vm.sh` and the `vmtest-core` check.
* Disk: ~30 GB free in `/nix/store` for a desktop closure plus ISO.

## Exact pinned inputs

| Input | Value |
|---|---|
| nixpkgs | `git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05` |
| revision | `f68407657ad294471eb4b2e65d193df26edf729f` (2026-11-16) |
| narHash | `sha256-E+XLAfnC7+bdr4qlEgRv6cdGmiqTU5oeFNKCha7epqQ=` |
| Resolved | NixOS 26.05, Linux 6.18.63, Mesa 26.1.8, Plasma 6.6.6 |

## Commands

```sh
# Evaluation checks (fast, no building, no binary cache needed)
scripts/check.sh

# Full checks: lint + QEMU boot test
scripts/check.sh --full

# Build one host's system closure without installing it
nix build .#nixosConfigurations.desktop-amd.config.system.build.toplevel

# Desktop VM (login: freutigo / freutigo — development only)
scripts/test-vm.sh

# Installer ISO → dist/*.iso + .sha256 + .buildinfo
scripts/build-iso.sh
scripts/build-iso.sh --offline-host <host-without-steam>   # offline installer

# Boot the ISO in QEMU (UEFI by default, --bios for legacy)
scripts/test-vm.sh --iso
scripts/test-vm.sh --iso --bios

# Development shells
nix develop                 # nixfmt, statix, deadnix, shellcheck, qemu
nix develop .#cat-arena     # cmake, ninja, SDL3, Vulkan headers/loader/layers, glslc, gdb, renderdoc
nix fmt                     # format all Nix files
```

## Notes

* Flakes only see files tracked by git. `git add` new files before building
  (`scripts/check.sh` refuses to run while `.nix`/`.sh` files are untracked).
* `desktop-nvidia-legacy` refuses to evaluate until the owner sets
  `freutigo.hardware.nvidia.acceptLegacyLicense = true`. CI evaluation forces
  it on purely to type-check; that is not a licence acceptance.
* The development VM password lives in the Nix store (world-readable). Never
  use `freutigo.user.initialPassword` on a real installation.

## F0 build environment (what was actually run)

| Item | Value |
|---|---|
| Host | Ubuntu 24.04.5 container, Linux 6.18.44, 2 vCPU, 8 GB RAM |
| Nix | 2.34.6 |
| Network | git access to github.com only; **cache.nixos.org blocked** |
| Consequence | Evaluation verified; **no builds performed** (would require compiling the whole OS from source, and source tarball hosts were also unreachable). |
