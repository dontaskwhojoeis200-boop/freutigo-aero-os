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
# Minimal console VM (core OS, no desktop), serial console in the terminal
nix run .#vm-minimal

# Installer ISO → dist/*.iso + .sha256 + .buildinfo
scripts/build-iso.sh
scripts/build-iso.sh --offline-host <host-without-steam>   # offline installer

# Boot the ISO in QEMU (UEFI by default, --bios for legacy)
scripts/test-vm.sh --iso
scripts/test-vm.sh --iso --bios

# End-to-end: install from the ISO into a blank QEMU disk, then boot it
OVMF_CODE=… OVMF_VARS=… scripts/e2e-install-test.sh --iso dist/*.iso --firmware uefi [--desktop]
scripts/e2e-install-test.sh --iso dist/*.iso --firmware bios

# Installer dry run (no disk access): writes the generated configuration
scripts/freutigo-install.sh --dry-run --answers answers.env --source . --target /tmp/x/etc/freutigo

# GPU detection fixture tests (no hardware needed)
tests/gpu-detect/run.sh

# Development shells
nix develop                 # nixfmt, statix, deadnix, shellcheck, qemu
nix develop .#cat-arena     # cmake, ninja, SDL3, Vulkan headers/loader/layers, glslc, gdb, renderdoc
nix fmt                     # format all Nix files
```

## Continuous integration (GitHub Actions)

`.github/workflows/ci.yml` runs on every push to `main`, on pull requests
and on tags `f*`/`v*`, on GitHub's `ubuntu-24.04` runners (KVM, full access
to cache.nixos.org):

| Job | What it proves |
|---|---|
| eval | `scripts/check.sh` (every host, GPU profile, ISO), GPU-detection fixtures, installer dry run whose generated config is evaluated |
| lint | shellcheck, sandboxed gpu-detect check, nixfmt (advisory) |
| vm-tests | `vmtest-core` (core OS boots, services, security invariants), `vmtest-desktop` (SDDM → Plasma Wayland login); screenshots uploaded |
| iso | builds the ISO with checksum + buildinfo; uploaded as artifact `freutigo-iso` |
| e2e | `uefi-minimal`, `bios-minimal`, `uefi-desktop`: unattended install from the built ISO, then boot of the installed disk; serial logs uploaded |
| release | on tags only: GitHub pre-release with ISO, checksum, buildinfo |

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
