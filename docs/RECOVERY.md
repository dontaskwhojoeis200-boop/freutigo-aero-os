# Recovery

> F0 draft. These procedures use standard NixOS mechanisms present in the
> configuration (generation menu, `text-console` entry). They have **not yet
> been exercised** on a Freutigo build; F7 tests each one.

## What rollback does and does not do

* **System generations** restore the *operating system* (packages, services,
  drivers, `/etc`) to an earlier state.
* They **do not** restore personal files. Deleted or damaged documents in
  `/home` must come from a backup. See "Backups" below.

## Boot menu

Every successful `nixos-rebuild` creates a generation. The boot menu
(systemd-boot on UEFI, GRUB on BIOS) shows the last 20 generations, each with a
second **`text-console`** entry that boots the same system without the
graphical session. Generations are never garbage-collected automatically.

## Failed desktop startup / broken graphics driver

1. Reboot. In the boot menu choose the **previous generation**, or the
   current generation's **text-console** entry.
2. Log in on the text console.
3. Check the driver: `freutigo-gpu-diagnostics`, `journalctl -b -1 -p err`.
4. Fix the host file (e.g. switch `freutigo.hardware.gpuProfile`, or set
   `freutigo.desktop.mode = "aero-lite"`), then:
   ```sh
   cd /etc/freutigo && sudo nixos-rebuild boot --flake .#<host>
   ```
   and reboot.

## Failed system update

```sh
sudo nixos-rebuild switch --rollback     # back to the previous generation now
```
or pick the older generation in the boot menu, then make it the default:
```sh
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration boot
```
Undo the flake update itself with `git checkout flake.lock`.

## Invalid Nix configuration

An invalid configuration fails at evaluation time and **changes nothing**:
the running system and boot menu stay as they were. Run `scripts/check.sh`
for an explanation, fix the file, and rebuild. `git diff` / `git checkout`
in `/etc/freutigo` reverts edits.

## Incorrect display settings

* Wait for the confirmation countdown: Plasma reverts resolution/refresh changes that are not confirmed.
* Otherwise log in on the `text-console` entry and remove the user's display
  configuration: `rm -r ~/.local/share/kscreen` (it is recreated on next login).

## Bootloader problems (system does not boot at all)

1. Boot the Freutigo ISO.
2. Mount the installed system:
   ```sh
   mount /dev/disk/by-label/FREUTIGO_ROOT /mnt
   mount /dev/disk/by-label/FREUTIGO_EFI /mnt/boot        # UEFI only
   ```
3. Reinstall the bootloader from the existing system configuration:
   ```sh
   nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
   ```
4. Reboot.

## Text console recovery path (summary)

`text-console` boot entry → log in → `freutigo-gpu-diagnostics` →
edit `/etc/freutigo/hosts/<host>/default.nix` → `sudo nixos-rebuild boot --flake /etc/freutigo#<host>` → reboot.
If even that fails: ISO → `nixos-enter --root /mnt` → same commands.

## Backups

Rollback is not a backup. Planned (F6): an optional graphical backup utility.
Until then, copy `/home/<user>` to an external drive regularly, e.g.
`rsync -a --delete ~/ /run/media/$USER/<drive>/home-backup/`, and keep the
`/etc/freutigo` git repository pushed somewhere off the machine.
