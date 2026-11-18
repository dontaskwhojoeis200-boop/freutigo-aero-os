# Installation

> **DRAFT: not yet executed.** This procedure is written for the F1 milestone
> and has not been run, in a VM or on hardware. It uses the standard NixOS
> flake installation workflow. A branded graphical installer is planned for F6.

## Internet access

The F0/F1 ISO is an **online installer**: packages are downloaded from
`cache.nixos.org` during installation, and Steam (if enabled) is built from
Valve's bootstrap. An offline ISO can be produced with
`scripts/build-iso.sh --offline-host <host>` for hosts without Steam.

## 1. Boot the ISO

Write `freutigo-aero-os-*.iso` to a USB stick (verify the `.sha256` first),
boot it, and choose UEFI or legacy boot in the firmware menu. You get a root
shell (`sudo -i`). Connect to Wi-Fi with `nmtui` if needed.

## 2. Partition (explicit, destructive)

**Nothing is partitioned automatically.** Identify the target disk carefully:

```sh
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,MOUNTPOINT
```

### UEFI, whole disk (ERASES `/dev/sdX`)

```sh
DISK=/dev/sdX            # ← double-check this
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n FREUTIGO_EFI "${DISK}1"
mkfs.ext4 -L FREUTIGO_ROOT "${DISK}2"
mount /dev/disk/by-label/FREUTIGO_ROOT /mnt
mkdir -p /mnt/boot && mount -o umask=077 /dev/disk/by-label/FREUTIGO_EFI /mnt/boot
```

### Legacy BIOS

Use an MBR (`mklabel msdos`) with one ext4 partition labelled `FREUTIGO_ROOT`,
and later set in the host file:

```nix
freutigo.boot.mode = "bios";
freutigo.boot.biosDevice = "/dev/disk/by-id/<your-disk>";
```

### Dual boot with Windows

* Shrink the Windows partition **from Windows** (Disk Management) first, and
  back up your data.
* UEFI: **reuse** the existing EFI system partition. Mount it at `/mnt/boot`
  and do **not** format it. systemd-boot detects Windows Boot Manager.
* Create only the new ext4 root partition in the freed space.
* Windows Fast Startup must be disabled to mount NTFS volumes read-write.

## 3. Prepare the configuration

```sh
mkdir -p /mnt/etc
cp -rL /etc/freutigo/source /mnt/etc/freutigo && chmod -R u+w /mnt/etc/freutigo
cd /mnt/etc/freutigo
HOST=desktop-amd          # desktop-amd | desktop-nvidia | desktop-nvidia-legacy
nixos-generate-config --root /mnt --show-hardware-config > hosts/$HOST/hardware-configuration.nix
git init -q 2>/dev/null; git add -A          # flakes only see tracked files
```

Optionally edit `hosts/$HOST/default.nix`: user name (`freutigo.user.name`),
`time.timeZone`, `console.keyMap`, `i18n.defaultLocale`, `freutigo.desktop.mode`.

## 4. Install

```sh
nixos-install --flake /mnt/etc/freutigo#$HOST --no-root-passwd
nixos-enter --root /mnt -c 'passwd freutigo'     # set the user's password
reboot
```

## 5. After first boot

```sh
freutigo-gpu-diagnostics     # verify the graphics stack (section 5.5)
```

Report the output with the hardware matrix in docs/COMPATIBILITY.md.
