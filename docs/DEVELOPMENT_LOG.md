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
