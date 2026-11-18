# Installation

Status: the guided installer is **implemented and tested in QEMU by CI**
(see DEVELOPMENT_LOG.md for the exact runs). It has **not** yet been run on
real hardware.

## Before you start

* **Back up your data.** An installation that erases a disk cannot be undone.
* **Internet is required.** The ISO is an online installer: the system
  (≈1 GB minimal, several GB with the desktop) is downloaded from
  `cache.nixos.org`. Wired Ethernet is simplest; Wi-Fi works through `nmtui`.
* Firmware: UEFI and legacy BIOS are both supported. Boot the USB stick in the
  mode you want the installed system to use.

## 1. Write and boot the ISO

Verify the download, then write it to a USB stick (≥ 2 GB, erased):

```sh
sha256sum -c freutigo-aero-os-*.iso.sha256
sudo dd if=freutigo-aero-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync   # Linux
```

On Windows use Rufus (DD mode) or balenaEtcher. Boot from the stick. You are
logged in automatically and see the Freutigo help box.

## 2. Run the installer

```sh
sudo freutigo-install
```

It asks, in order:

| Step | Question | Notes |
|---|---|---|
| 1 | Network | Checks `cache.nixos.org`; offers `nmtui` if offline |
| 2 | Locale, keyboard, time zone | Keyboard applies immediately; desktop layout is derived where possible |
| 3 | Computer name, login name, full name, password | Password entered twice, never written to disk or log |
| 4 | Graphics profile | Auto-detected (`freutigo-detect-gpu`), shown with the reason; type another profile to override. `nvidia-legacy-470` requires accepting NVIDIA's licence |
| 4 | Desktop yes/no, Aero or Aero Lite, Steam yes/no | Aero Lite recommended for 1 GB VRAM cards |
| 5 | Firmware, disk mode, disk | See below |
| 6 | Summary | Type `install` to begin; anything else aborts with nothing changed |

### Disk modes

* **erase**: erases one whole disk. You must type the exact disk path
  (e.g. `/dev/sda`) to confirm. The installer media cannot be selected.
  Layout: UEFI = 1 GiB EFI (FAT32, `FREUTIGO_EFI`) + ext4 root
  (`FREUTIGO_ROOT`); BIOS = GPT with a 1 MiB BIOS-boot partition + ext4 root.
  No swap partition (memory optimisation is evaluated in F5).
* **mounted**: never formats anything. Create and mount the partitions
  yourself first, which is the mode for dual boot:

  ```sh
  mount /dev/disk/by-label/<your-root> /mnt
  mount /dev/<existing-EFI-partition> /mnt/boot      # UEFI: reuse Windows' ESP, do NOT format it
  sudo freutigo-install                               # choose disk mode "mounted"
  ```

### Dual boot with Windows

1. In Windows: back up, disable Fast Startup, shrink the Windows partition in
   Disk Management to free space.
2. Boot the ISO, create one ext4 partition in the free space
   (`sudo cfdisk /dev/sdX`, then `sudo mkfs.ext4 -L FREUTIGO_ROOT /dev/sdXN`).
3. Mount it at `/mnt` and the existing EFI partition at `/mnt/boot`, and run
   the installer in **mounted** mode. systemd-boot lists Windows Boot Manager.

## 3. What the installer writes

The complete Freutigo source tree is copied to `/etc/freutigo` (a git
repository) with your machine in `hosts/local/`:

* `default.nix`: your answers, readable and editable.
* `hardware-configuration.nix`: from `nixos-generate-config`, with file
  systems referenced by label when the installer formatted the disk.

The system is built with `nixos-install --flake /etc/freutigo#local`.
Change settings later by editing `hosts/local/default.nix` and running
`sudo nixos-rebuild boot --flake /etc/freutigo#local`, then reboot.
The install log is kept at `/var/log/freutigo-install.log`.

## 4. After first boot

```sh
freutigo-gpu-diagnostics      # verify the graphics stack (section 5.5)
```

Please report its output for the hardware matrix in COMPATIBILITY.md.

## Unattended installation

Create a small FAT disk or USB stick labelled `FREUTIGO_AUTO` containing
`answers.env` and attach it when booting the ISO. The installer starts by
itself and logs to the console and serial port:

```sh
LOCALE=en_US.UTF-8
KEYMAP=us
TIMEZONE=UTC
HOSTNAME=freutigo
USERNAME=user
FULLNAME=Freutigo User
PASSWORD=change-me
GPU_PROFILE=auto            # or a profile name
ACCEPT_NVIDIA_LICENSE=no    # only for nvidia-legacy-470
DESKTOP=yes
DESKTOP_MODE=aero           # aero | aero-lite
STEAM=yes
FIRMWARE=auto               # auto | uefi | bios
DISK_MODE=erase             # erase | mounted
DISK=/dev/sda
CONFIRM_ERASE=/dev/sda      # must repeat DISK exactly, or nothing happens
REBOOT=yes                  # yes | poweroff | no
```

Without a matching `CONFIRM_ERASE` the installer refuses to erase anything.
The password is in plain text on that stick: delete the file afterwards.

## Manual installation (fallback)

The standard NixOS flake workflow always works from the ISO shell:
partition and mount at `/mnt`, then

```sh
cp -rL /etc/freutigo/source /mnt/etc/freutigo && chmod -R u+w /mnt/etc/freutigo
cd /mnt/etc/freutigo && mkdir -p hosts/local
nixos-generate-config --root /mnt --show-hardware-config > hosts/local/hardware-configuration.nix
$EDITOR hosts/local/default.nix          # see hosts/desktop-amd for an example
git init -q && git add -A
nixos-install --flake /mnt/etc/freutigo#local --no-root-passwd
nixos-enter --root /mnt -c 'passwd <user>'
```
