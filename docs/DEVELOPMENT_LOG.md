# Development log

Verification ladder: Designed → Implemented → Evaluated → Compiled → Booted in
VM → Tested on hardware · Unverified · Blocked.

---

## F0 — Architecture and Build Environment — 2026-11-17 — COMPLETE

### Implemented

* Repository structure per section XII (plus `lib/`, `hosts/common/`).
* `flake.nix` with nixpkgs pinned to `nixos-26.05` @
  `f68407657ad294471eb4b2e65d193df26edf729f` via `flake.lock`.
* Core modules: base (branding, Nix settings, unfree allowlist, CPU-baseline
  assertion), boot (systemd-boot / GRUB, 20-entry menu, `text-console`
  recovery specialisation), kernel (6.18 LTS, firmware, microcode), services,
  networking, audio (PipeWire), security (assertions), storage, users.
* Seven isolated GPU profiles + registry in `lib/`.
* Desktop: Plasma 6 foundation, Aero / Aero Lite compositor defaults through a
  system-wide KDE INI mechanism (`freutigo.desktop.kdeDefaults`), Baloo off.
* Gaming: Steam/Proton/Proton-GE, GameMode, controller rules, Vulkan tools,
  direnv; `cat-arena` dev shell (C++20, SDL3, Vulkan, shader tools).
* Optimisation candidates (zram, noatime, ModemManager, BT power) as options,
  all off.
* Hosts: desktop-amd, desktop-nvidia, desktop-nvidia-legacy, virtual-machine,
  installation-iso (minimal NixOS installer base, Freutigo branding, source
  tree in `/etc/freutigo/source`, optional offline closure, no ZFS, no Steam).
* Packages: `freutigo-gpu-diagnostics` (section 5.5), `freutigo-benchmark`
  (section 6.1 method, PSS + cgroup grouping).
* Scripts: check, build-iso (checksums + buildinfo), test-vm (VM host or ISO,
  UEFI/BIOS), diagnostics, benchmark.
* Checks: 13 evaluation checks, shellcheck, nixfmt, `vmtest-core` QEMU test.
* Docs: all files in `docs/`.

### Validation actually performed

| Check | Result |
|---|---|
| `nix flake lock` against real nixos-26.05 | ✅ |
| Option names verified against pinned nixpkgs source | ✅ |
| `scripts/check.sh`: 5 hosts + 7 profiles + ISO image fully evaluated | ✅ 13/13 |
| Resolved values (desktop-amd): kernel 6.18.63, Mesa 26.1.8, amdgpu SI/CIK params, initrd amdgpu, session `plasma`, `text-console` specialisation, kwinrc/baloofilerc content, root locked | ✅ inspected |
| `desktop-nvidia-legacy` without licence acceptance fails with Freutigo's message | ✅ |
| `vmtest-core`, dev shells, packages, VM derivations evaluate | ✅ |
| `bash -n` on all scripts | ✅ |
| `benchmark.sh` executed (container) | ✅ report correct |
| `diagnostics.sh` executed (container, no GPU) | ✅ graceful exit 2 |
| Build any derivation | ❌ **Blocked**: cache.nixos.org unreachable |
| shellcheck / nixfmt | ❌ **Blocked**: tools not buildable here |
| QEMU boot | ❌ **Blocked**: nothing built |

### Bugs found by evaluation and fixed during F0

1. Host hostname vs. module default at equal priority → distro default lowered
   below `mkDefault`.
2. `PermitRootLogin` conflict with the NixOS installer profile → ISO keeps the
   upstream installer value; installed systems keep `"no"`.
3. X11 session lacked `services.xserver.enable` → SDDM assertion; fixed.
4. NVIDIA 470 needs licence acceptance + `nvidia-kernel-modules` unfree name
   → explicit owner option; CI-only override.
5. ZFS default warning in ISO → ZFS removed from installer.
6. VM test: hostPlatform / root-password interactions with the test harness.

### Unresolved / carried forward

* **No build has been performed.** First action of F1 on a machine with
  cache.nixos.org access: `scripts/check.sh --full`, then `scripts/build-iso.sh`.
* Nix files were hand-formatted; `nix fmt` may reformat some of them, and
  the `nix-format` check fails until it is run once.
* Repository licence not chosen (owner decision).
* NVK maturity on Kepler, nouveau reclocking: F3 investigation.
* Plasma idle memory vs. 1 GiB target: unknown until F5 measurement.

### Preserved working version

Git commit tagged `f0` is the last fully evaluated configuration.

---

## F1 — Minimal Bootable Freutigo OS — 2026-11-18

### Build environment

The F0 workspace still had no binary cache and no KVM, so F1 builds and
boots run on **GitHub Actions** (`ubuntu-24.04`, KVM, cache.nixos.org) in the
public repository `dontaskwhojoeis200-boop/freutigo-aero-os`.
Workflow: `.github/workflows/ci.yml` (see BUILD.md).

### Implemented

* `freutigo-detect-gpu`: GPU-profile detection driven by the kernel's
  `modules.alias` (AMD GCN 1.0/1.1 = claimable by both radeon and amdgpu),
  nouveau's chipset log line (NVIDIA family), vendor IDs (Intel, virtual).
  Device-ID tables only as fallback. 16 fixture tests.
* `freutigo-install`: guided and unattended installer: network check,
  locale/keymap/timezone, user + password, GPU profile with override and
  NVIDIA licence prompt, desktop/mode/Steam, UEFI/BIOS, **erase** (typed
  disk-path confirmation, installer media excluded) or **mounted** mode
  (never formats; dual boot), summary + typed `install`, writes
  `/etc/freutigo/hosts/local`, `nixos-install --flake`, password via chpasswd.
  `--dry-run` writes the configuration without touching disks.
* ISO: installer + detector, help box, serial console, journal on serial,
  `AERO_AUTO` unattended mode, pinned nixpkgs source included, no ZFS.
* Hosts: `vm-minimal`; optional `local` (installed machines).
* Tests: `vmtest-desktop`, `gpu-detect`, stronger `vmtest-core`;
  `scripts/e2e-install-test.sh` (install from ISO into a blank QEMU disk,
  then boot that disk and wait for a serial boot report).
* CI: eval → lint, VM tests, ISO → E2E (uefi-minimal, bios-minimal,
  uefi-desktop) → release on tags.
* Nix sources formatted with nixfmt 1.5.0 (diff produced in CI).

### Bugs found by testing and fixed

| # | Found by | Bug |
|---|---|---|
| 1 | E2E | FAT labels > 11 characters: `FREUTIGO_EFI` would have made **every UEFI install fail** at mkfs; renamed `FREUTIGOEFI`; answers disk `AERO_AUTO` |
| 2 | E2E | Installer rejected `KEYMAP=us` on the ISO (keymaps live in the kbd package); would have blocked every interactive install at step 2 |
| 3 | E2E | Autoinstall service killed by systemd's 90 s start timeout |
| 4 | E2E | Autoinstall success/failure judged by `tee`'s exit status (twice) |
| 5 | E2E | Installer's own poweroff raced the success report → `--no-reboot` |
| 6 | dry run | Detector not executable when called from the source tree → installer continued with empty variables |
| 7 | CI shellcheck | Comma-containing QEMU arguments (SC2054) |
| 8 | vmtest-core | Wrong PipeWire path assumption; timesyncd is disabled by NixOS inside test VMs |
| 9 | vmtest-desktop | Forcing `virtualisation.qemu.options` removed the VM's direct kernel boot |
| 10 | vmtest-desktop | Wrapped `kwin_wayland` process name; SDDM focus race → retrying login |

### Validation (CI evidence)

| Check | Result |
|---|---|
| eval (14 configurations + installer dry run → generated config evaluates) | ✅ |
| lint (shellcheck, nixfmt, gpu-detect) | ✅ |
| `vmtest-core` | ✅ boots; NetworkManager, resolved, Bluetooth service; PipeWire answers in a user session; firewall active; sudo requires password; exFAT/NTFS/FAT tools; diagnostics run |
| `vmtest-desktop` | ✅ SDDM greeter → password login → plasmashell + KWin Wayland, `XDG_SESSION_TYPE=wayland`, PipeWire (3 consecutive passes) |
| ISO build | ✅ |
| E2E **uefi-minimal** | ✅ install from ISO (5 min) → reboot from disk (systemd-boot menu incl. text-console entry) → 0 failed units; NetworkManager, resolved, timesyncd active |
| E2E **bios-minimal** | ✅ install (3 min, GRUB on /dev/vda) → reboot from disk → 0 failed units |
| E2E **uefi-desktop** | ✅ install with Plasma (6.5 min) → reboot from disk → display-manager active, 0 failed units |

All 8 CI jobs green in run 44382486585 (commit ec229ad).

Informational only, NOT benchmarks (QEMU VMs, ~20 s after boot/login, no
10-minute settle, not the section 6.1 method): console system 361–366 MiB
used, desktop system at the SDDM greeter 693 MiB, desktop VM after login
936 MiB (Total − Available). `systemd-analyze` had not finished boot
accounting when the E2E report ran, so no boot time is recorded.

### F1 acceptance

"The OS boots successfully in a virtual machine and provides a usable system
session": **met in VM** (console and Plasma Wayland sessions, installed from
the ISO on UEFI and BIOS). Status on the verification ladder:
**Booted in VM**. Real hardware: **Unverified** (no GPU profile has been
exercised on a physical card).

### Unresolved / carried forward

* Real-hardware installation on the reference PC (R9 270 / HD 7850 / GTX 660).
* The text-console boot entry is present in the menu but has not been
  booted by a test; add an E2E variant in F2.
* Offline installation (`--offline-host`) needs build-time dependencies in
  the ISO, not just the runtime closure; untested, treat as unsupported.
* Interactive (non-unattended) installer prompts are exercised only through
  the same code paths with answers; a keyboard-driven VM test is F2 work.
* The `f0` git tag could not be pushed from the build session (git proxy
  refused tag pushes); tags are created through the GitHub API instead.

---

## F1.1 — Radeon R7 250 compatibility — 2026-11-18

### Research (sources checked, not assumed)

* Linux 6.18 `amdgpu_drv.c`: Oland `6608 6610 6611 6613 6631` (+ mobility
  IDs) and Cape Verde `6820–683F` are in amdgpu's SI table.
* pci.ids: R7 250 = `6610` (Oland XT), `682B` (Cape Verde PRO); R7 250X =
  `683D`; R7 250E = `683F`.
* Linux 6.18 `amdgpu_device.c`: Tahiti/Pitcairn/Verde/Oland use DC only when
  `amdgpu.dc=1`; the default legacy display code (`dce_v6_0.c`) registers
  DAC encoders, so VGA works. DC analog support was merged for Linux 6.19.
  **Correction:** the F0 statement "amdgpu does not drive analog outputs" was
  wrong for this kernel and has been fixed in HARDWARE.md.

### Implemented

* `freutigo-detect-gpu`: reports VRAM (`VRAM_MIB`) from amdgpu sysfs or the
  radeon/amdgpu `VRAM: <n>M` probe line (format verified in 6.18 source).
* `freutigo-install`: shows VRAM; defaults to Aero Lite below 2 GiB.
* `amd-gcn-legacy`: R7 250 documented; assertion refusing `amdgpu.dc=1` on
  kernels < 6.19 (verified to trigger on 6.18.63).
* `freutigo-gpu-diagnostics`: warns about `amdgpu.dc=1` with a connected
  VGA/DVI-I output on kernels < 6.19.
* Tests: 7 new fixtures (4 R7 250 PCI IDs, VRAM from log and sysfs, with and
  without `modules.alias`): 23/23 pass. Installer dry run with a simulated
  1 GB Oland R7 250 selects `amd-gcn-legacy` + `aero-lite`.

### Status

R7 250: **Evaluated** (detection tested with fixtures). Real hardware,
including a VGA monitor and a 1 GB DDR3 board: **Unverified**.
