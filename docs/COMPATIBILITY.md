# Compatibility matrix

Status ladder (Rule 4): **Designed → Implemented → Evaluated → Compiled →
Booted in VM → Tested on hardware**, plus **Unverified** (no evidence) and
**Blocked**. A status is raised only with evidence recorded in
DEVELOPMENT_LOG.md.

## GPU profiles

| Profile | Hardware | Status | Supported? |
|---|---|---|---|
| amd-gcn-legacy | Radeon R9 270 | Evaluated | Unverified |
| amd-gcn-legacy | Radeon HD 7850 (1 GB / 2 GB) | Evaluated | Unverified |
| amd-gcn-legacy | Radeon R7 250 / 250X / 250E (Oland, Cape Verde; 1–2 GB) | Evaluated; detection tested with fixtures for all 4 PCI IDs | Unverified |
| nvidia-kepler-oss | GeForce GTX 660 | Evaluated | Unverified |
| nvidia-legacy-470 | GeForce GTX 660 | Evaluated (CI licence override) | Experimental |
| amd-modern | GCN 3+/RDNA | Evaluated | Unverified |
| nvidia-modern | Turing+ | Evaluated | Unverified |
| intel | Intel iGPU | Evaluated | Unverified |
| virtual-machine | QEMU/KVM virtio-gpu / std VGA | **Booted in VM** (CI) | Supported for testing only |

## Hosts / artifacts

| Target | Status |
|---|---|
| desktop-amd | Evaluated |
| desktop-nvidia | Evaluated |
| desktop-nvidia-legacy | Evaluated (CI licence override) |
| virtual-machine | **Booted in VM**: `vmtest-desktop` passes (SDDM → Plasma Wayland) |
| vm-minimal | Evaluated (same core as `vmtest-core`) |
| installation-iso | **Booted in VM**: E2E install + reboot passes on UEFI and BIOS (minimal) and UEFI (desktop) |
| vmtest-core | **Passes** in CI |
| vmtest-desktop | **Passes** in CI |

## Features

| Feature | Status | Notes |
|---|---|---|
| Plasma 6.6 Wayland session | **Booted in VM** | SDDM password login → plasmashell + kwin_wayland, XDG_SESSION_TYPE=wayland |
| Plasma X11 session (fallback) | Evaluated | used by nvidia-legacy-470 |
| Aero / Aero Lite compositor defaults | Implemented (skeleton) | theme assets are F2 |
| PipeWire audio (+32-bit ALSA) | **Booted in VM** | PipeWire answers in a user session (no sound card in VM) |
| NetworkManager, resolved, Bluetooth | **Booted in VM** | services active; no BT adapter in VM |
| Firewall, locked root, sudo needs password | **Booted in VM** | `vmtest-core` |
| Guided installer (`freutigo-install`) | **Booted in VM** (unattended E2E) | interactive prompts share the same code paths |
| GPU auto-detection | **Tested** with 16 fixtures (incl. R9 270, HD 7850, GTX 660) | not yet on real hardware |
| NTFS / exFAT / FAT32 / ext4 / USB | Evaluated | |
| Firefox | Evaluated | Chromium: install path in F2 |
| Steam + Proton (+ Proton-GE) | Evaluated | not in ISO by design |
| GameMode, controller udev rules | Evaluated | |
| Vulkan/OpenGL diagnostics tool | Implemented; ran in container | GPU paths unexercised |
| Idle benchmark tool | Implemented; ran in container | |
| Cat Arena dev shell | Evaluated | |
| Recovery `text-console` entry | **Present in boot menu** (E2E serial log); not yet booted by a test | |

## Known limitations (to be confirmed, not assumed)

* Anti-cheat: many kernel-level anti-cheat titles do not run under Proton.
* DirectX 12 titles via VKD3D-Proton need Vulkan features GCN 1.0 / Kepler
  may lack; DX9–11 via DXVK depend on driver extension support.
* Games requiring AVX/AVX2 cannot run on the Pentium G2020, on any OS.
* Linux browsers often get lower DRM tiers (e.g. lower streaming resolution).
