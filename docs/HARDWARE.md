# Hardware

## Reference platform

| Component | Specification | Notes |
|---|---|---|
| CPU | Intel Pentium G2020 (Ivy Bridge, 2C/2T) | SSE4.2/POPCNT, **no AVX**. System compiled for generic x86-64; `nixpkgs.hostPlatform.gcc.arch` is restricted to `x86-64`/`x86-64-v2` by assertion. |
| RAM | 8 GB DDR3 | Idle target < 1 GiB used |
| Storage | 5400 RPM SATA HDD (SSD optional) | Baloo indexing off, bounded journal, weekly fstrim (no-op on HDD) |
| GPU | R9 270 (primary), HD 7850, R7 250, GTX 660 | See profiles below |
| Display | 1920×1080 @ 60 Hz (up to 144 Hz) | |

## AMD Radeon R9 270 / HD 7850 → `amd-gcn-legacy`

Both are Pitcairn-family **GCN 1.0 (Southern Islands)** GPUs. Linux binds SI
and CIK GPUs to the old `radeon` driver by default, which has **no Vulkan**.
The profile enables `hardware.amdgpu.legacySupport`, which adds:

```
amdgpu.si_support=1 amdgpu.cik_support=1 radeon.si_support=0 radeon.cik_support=0
```

and loads `amdgpu` in the initrd. Vulkan uses Mesa RADV (AMDVLK is not
installed). Verified by evaluation: these parameters are present in the
`desktop-amd` system.

Caveats:

* **Analog outputs (VGA, DVI-I analog).** *Corrected in F1.1: F0 stated that
  amdgpu cannot drive analog outputs, copied from the NixOS option text. That
  is not true for Linux 6.18.* For SI chips (Tahiti, Pitcairn, Cape Verde,
  Oland) Linux 6.18 keeps amdgpu on its **legacy (non-DC) display code by
  default** (`amdgpu_device_asic_has_dc_support` returns `amdgpu_dc > 0`,
  "systems in the wild … require LVDS and VGA support"), and that code has
  DAC encoders, so VGA works. Only the newer DC display code lacked analog
  support until Linux 6.19. The profile therefore **refuses `amdgpu.dc=1`
  on kernels older than 6.19**, and `freutigo-gpu-diagnostics` warns if it is
  set while a VGA/DVI-I connector is in use. Status: verified in kernel
  source, **unverified on hardware**.
* HD 7850 and R7 250 boards exist with 1 GB and 2 GB VRAM. The installer
  reads the exact amount (amdgpu sysfs, or the driver's `VRAM: <n>M` probe
  line) and defaults to **Aero Lite below 2 GiB**; `freutigo-gpu-diagnostics`
  warns below 2 GiB too.

Required real-hardware checks (F3): `lspci -k` shows `amdgpu`; `vulkaninfo`
lists a RADV device; `glxinfo -B` shows radeonsi with Accelerated: yes; KWin
compositing works on Wayland; Steam launches; vkcube runs.

## AMD Radeon R7 250 → `amd-gcn-legacy`

Added in F1.1. "R7 250" is sold on two different GCN 1.0 chips:

| PCI ID | Chip | Retail names (pci.ids) |
|---|---|---|
| `1002:6610` | Oland XT | R7 250 / R7 350 / HD 8670 |
| `1002:682B` | Cape Verde PRO | R7 250 |
| `1002:683D` | Cape Verde XT | R7 250X (also HD 7770) |
| `1002:683F` | Cape Verde PRO | R7 250E (also HD 7750) |

All four are in Linux 6.18's amdgpu and radeon ID tables, so
`freutigo-detect-gpu` selects `amd-gcn-legacy` from the kernel's own
`modules.alias`; the device-ID fallback table covers them too (fixture tests
for every variant, with and without `modules.alias`). Same driver stack as the
R9 270: amdgpu + Mesa radeonsi (OpenGL) + RADV (Vulkan), 32-bit libraries.

R7 250–specific points:

* **Low VRAM and memory type.** Many boards have 1 GB, and many use DDR3 rather
  than GDDR5 (much lower bandwidth). The installer suggests Aero Lite on
  1 GB cards; the compositor cost of full Aero blur on DDR3 boards must be
  measured in F5, not assumed.
* **VGA port.** Common on these boards; supported through amdgpu's default
  legacy display path on Linux 6.18 (see Caveats above). Do not set
  `amdgpu.dc=1`.
* **Oland vs. Cape Verde.** Oland is the smaller chip (fewer compute units);
  expect lower gaming performance than Cape Verde R7 250X/250E. The Vulkan
  version, features and extensions RADV exposes on each chip must be read with
  `vulkaninfo` on the real card.
* Not to be confused with Hainan (`1002:666x`): mobile-only, no display
  engine.

Required real-hardware checks: as for the R9 270, plus a VGA monitor test on
a board with a VGA port, and Aero vs. Aero Lite on a 1 GB DDR3 board.

## NVIDIA GeForce GTX 660 → `nvidia-kepler-oss` (default for this card)

Kepler (GK106). Kernel `nouveau`, OpenGL Mesa nouveau, Vulkan Mesa **NVK**
(Mesa 26.1.8 built with the nouveau Vulkan driver).

Known risks, to be measured in F3, not assumed:

* **Clocks:** nouveau starts Kepler GPUs at boot clocks. Without reclocking, 3D
  performance is a fraction of the proprietary driver's. Manual reclocking
  through nouveau's debugfs `pstate` interface exists for some Kepler boards
  but can hang the GPU; it is an F3 investigation item and is not configured.
* **NVK on pre-Turing GPUs** is newer and less mature than on Turing+. The
  available Vulkan version, features and extensions must be read from
  `vulkaninfo` on the real card. Advertised API version alone is not proof.

## NVIDIA GeForce GTX 660 → `nvidia-legacy-470` (EXPERIMENTAL, optional)

NVIDIA 470.256.02, the last branch supporting Kepler.

| Aspect | Implication |
|---|---|
| Support | End of mainstream support. nixpkgs carries community patches up to Linux 7.0; the 6.18 LTS kernel is currently covered. A future kernel can break the build; then pin an older LTS kernel with `freutigo.kernel.packages`. |
| Security | Closed-source kernel module; no upstream review. |
| Display | No GBM, so **no Plasma Wayland session**. The profile enforces X11 (`plasmax11`) and an X11 SDDM greeter. |
| Licence | nixpkgs requires accepting NVIDIA's licence. Set `freutigo.hardware.nvidia.acceptLegacyLicense = true` after reading it. Until then the host deliberately fails to evaluate with an explanatory message. |
| Isolation | nouveau is blacklisted only in this profile; AMD profiles are untouched. |

It stays outside the supported set until it is compared against nouveau/NVK on
the real card (reliability first, then performance).

## Other profiles

* `amd-modern`: GCN 3+/RDNA, amdgpu binds automatically.
* `nvidia-modern`: current production driver with NVIDIA's open kernel module
  (Turing+). Maxwell/Pascal: set `freutigo.hardware.nvidia.openKernelModule = false`.
* `intel`: i915/xe, Iris/ANV, VA-API via `intel-media-driver` (Gen8+) and
  `intel-vaapi-driver` (older, e.g. the G2020's HD Graphics).
* `virtual-machine`: QEMU/KVM with virtio-gpu, SPICE agent, guest agent.

## Selecting a profile

Profiles are chosen per host (`freutigo.hardware.gpuProfile`). Automatic
selection from PCI IDs, with manual override, is planned for the F6 installer.
The safe manual path is always available by editing the host file.
