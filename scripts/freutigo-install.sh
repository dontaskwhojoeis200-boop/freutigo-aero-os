#!/usr/bin/env bash
# freutigo-install — guided installer for Freutigo Aero OS (section 11.1)
#
#   sudo freutigo-install                    interactive installation
#   sudo freutigo-install --answers FILE     unattended (KEY=value file, see
#                                            docs/INSTALL.md "Unattended")
#   sudo freutigo-install --answers FILE --no-reboot
#                                            as above, but leave reboot/poweroff
#                                            to the caller (autoinstall service)
#   freutigo-install --dry-run [--answers FILE] --target DIR
#                                            generate the configuration into
#                                            DIR without touching any disk
#
# Safety: nothing is partitioned or formatted without an explicit typed
# confirmation of the exact disk path. "Use mounted partitions" mode never
# formats anything (dual boot / manual layouts).
set -euo pipefail

SOURCE=/etc/freutigo/source
ROOT=/mnt
ANSWERS=""
DRY_RUN=0
TARGET_OVERRIDE=""
NO_REBOOT=0
LOG=/tmp/freutigo-install.log

while [[ $# -gt 0 ]]; do
  case "$1" in
    --answers) ANSWERS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --source) SOURCE="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --target) TARGET_OVERRIDE="$2"; shift 2 ;;
    --no-reboot) NO_REBOOT=1; shift ;;   # caller handles reboot/poweroff
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- helpers --
if [[ -t 1 ]]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else B=""; G=""; Y=""; R=""; C=""; N=""; fi
log()   { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
title() { echo; echo "${B}${C}── $* ──${N}"; log "== $*"; }
note()  { echo "  $*"; log "$*"; }
warn()  { echo "  ${Y}! $*${N}"; log "WARN $*"; }
die()   { echo "${R}error: $*${N}" >&2; log "ERROR $*"; exit 1; }
run()   { log "+ $*"; if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $*"; else "$@" >> "$LOG" 2>&1; fi; }

# Answers, filled in by ask() via printf -v (declared for clarity/ShellCheck).
LOCALE=""; KEYMAP=""; TIMEZONE=""; HOSTNAME=""; USERNAME=""; FULLNAME=""
GPU_PROFILE=""; ACCEPT_NVIDIA_LICENSE=""; DESKTOP=""; DESKTOP_MODE=""; STEAM=""
FIRMWARE=""; DISK_MODE=""; DISK=""; BIOS_DEVICE=""; REBOOT=""

declare -A ANS=()
UNATTENDED=0
if [[ -n "$ANSWERS" ]]; then
  [[ -r "$ANSWERS" ]] || die "cannot read answers file $ANSWERS"
  UNATTENDED=1
  # Parse KEY=value lines without executing them.
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]] || die "bad line in answers file: $line"
    val=${BASH_REMATCH[2]}
    val=${val#\"}; val=${val%\"}
    ANS[${BASH_REMATCH[1]}]=$val
  done < "$ANSWERS"
fi

# ask KEY "Prompt" default validator-function
ask() {
  local key=$1 prompt=$2 def=$3 validator=${4:-true} v
  while true; do
    if [[ $UNATTENDED -eq 1 ]]; then
      v=${ANS[$key]-$def}
    else
      read -r -p "  $prompt [${def}]: " v || die "input closed"
      v=${v:-$def}
    fi
    if "$validator" "$v"; then printf -v "$key" '%s' "$v"; log "$key=$v"; return; fi
    [[ $UNATTENDED -eq 1 ]] && die "invalid value for $key: '$v'"
    warn "invalid value, try again"
  done
}
ask_yn() {  # KEY prompt default(yes|no)
  ask "$1" "$2 (yes/no)" "$3" is_yn
}
is_yn()       { [[ "$1" == yes || "$1" == no ]]; }
is_locale()   { [[ "$1" =~ ^[a-z]{2,3}_[A-Z]{2}(@[a-z]+)?\.UTF-8$ ]]; }
is_hostname() { [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; }
is_username() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && [[ ! " root nixos daemon bin nobody messagebus sddm " == *" $1 "* ]]; }
is_fullname() { [[ -n "$1" && "$1" != *$'\n'* && "$1" != *:* ]]; }
is_timezone() { [[ "$1" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] && { [[ $DRY_RUN -eq 1 ]] || [[ -e "/etc/zoneinfo/$1" ]]; }; }
is_keymap() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
  [[ $DRY_RUN -eq 1 ]] && return 0
  local d lk found_dir=0
  local -a dirs=()
  # On NixOS the keymaps ship with the kbd package next to loadkeys.
  if lk=$(command -v loadkeys 2>/dev/null); then
    dirs+=("$(dirname "$(readlink -f "$lk")")/../share/keymaps")
  fi
  dirs+=(/run/current-system/sw/share/keymaps /usr/share/keymaps /usr/share/kbd/keymaps /lib/kbd/keymaps)
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || continue
    found_dir=1
    find -L "$d" -name "$1.map*" -print -quit | grep -q . && return 0
  done
  if [[ $found_dir -eq 0 ]]; then
    log "WARN no keymap directory found; cannot validate keymap '$1'"
    return 0
  fi
  return 1
}
is_profile()  { [[ " $PROFILES auto " == *" $1 "* ]]; }
is_mode()     { [[ "$1" == aero || "$1" == aero-lite ]]; }
is_diskmode() { [[ "$1" == erase || "$1" == mounted ]]; }
is_firmware() { [[ "$1" == auto || "$1" == uefi || "$1" == bios ]]; }
is_disk()     { [[ -b "$1" ]] && [[ "$(lsblk -dno TYPE "$1" 2>/dev/null)" == disk ]]; }
is_reboot()   { [[ "$1" == yes || "$1" == no || "$1" == poweroff ]]; }
nonempty()    { [[ -n "$1" ]]; }

# Escape a string for a Nix double-quoted literal.
nix_str() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//\$\{/\\\$\{}
  printf '"%s"' "$s"
}

PROFILES="amd-gcn-legacy nvidia-kepler-oss nvidia-legacy-470 amd-modern nvidia-modern intel virtual-machine none"
if command -v freutigo-detect-gpu >/dev/null 2>&1; then
  DETECT=(freutigo-detect-gpu)
else
  DETECT=(bash "$(dirname "$0")/detect-gpu-profile.sh")
fi

: > "$LOG"
echo "${B}Freutigo Aero OS installer${N}  $(cat /etc/freutigo/version 2>/dev/null || echo dev)"
echo "  Log: $LOG  (no passwords are logged)"
[[ $DRY_RUN -eq 1 ]] && echo "  ${Y}DRY RUN: no disk will be touched and nothing will be installed.${N}"
if [[ $DRY_RUN -eq 0 && $EUID -ne 0 ]]; then die "run as root: sudo freutigo-install"; fi
[[ -f "$SOURCE/flake.nix" ]] || die "Freutigo source not found at $SOURCE"

# ----------------------------------------------------------------- 1 net --
title "1/7 Network"
if [[ $DRY_RUN -eq 1 ]]; then
  note "skipped in dry run"
else
  until curl -fsS -m 10 -o /dev/null https://cache.nixos.org/nix-cache-info; do
    warn "cannot reach cache.nixos.org. Packages are downloaded during installation."
    [[ $UNATTENDED -eq 1 ]] && die "no network (unattended)"
    echo "  Connect with: nmtui   (Wi-Fi and Ethernet). Press Enter to retry, Ctrl-C to abort."
    read -r _
  done
  note "${G}online${N}"
fi

# ------------------------------------------------------------ 2 language --
title "2/7 Language, keyboard, time zone"
ask LOCALE   "System language (locale)" "en_US.UTF-8" is_locale
ask KEYMAP   "Console keyboard layout (e.g. us, uk, de, fr, es)" "us" is_keymap
[[ $DRY_RUN -eq 0 ]] && loadkeys "$KEYMAP" >/dev/null 2>&1 || true
ask TIMEZONE "Time zone (e.g. America/Los_Angeles, Europe/Berlin)" "UTC" is_timezone

# xkb (desktop/login screen) layout from the console layout where they agree.
case "$KEYMAP" in
  uk) XKB=gb ;;
  us|de|fr|es|it|pt|se|no|dk|fi|pl|cz|sk|hu|ru|ua|tr|be|nl|ch|jp|br|ca|gr|il|lt|lv|ee|si|hr|ro|bg|rs|is|ie|latam) XKB=$KEYMAP ;;
  *) XKB="" ;;
esac

# ---------------------------------------------------------------- 3 user --
title "3/7 Computer name and user account"
ask HOSTNAME "Computer name" "freutigo" is_hostname
ask USERNAME "Login name (lowercase)" "user" is_username
ask FULLNAME "Full name (shown on the login screen)" "Freutigo User" is_fullname
if [[ $UNATTENDED -eq 1 ]]; then
  PASSWORD=${ANS[PASSWORD]-}
  [[ -n "$PASSWORD" ]] || die "PASSWORD missing in answers file"
else
  while true; do
    read -r -s -p "  Password for $USERNAME: " PASSWORD; echo
    read -r -s -p "  Repeat password: " p2; echo
    [[ -n "$PASSWORD" && "$PASSWORD" == "$p2" ]] && break
    warn "passwords empty or different, try again"
  done
fi
log "PASSWORD=(hidden)"

# ----------------------------------------------------------------- 4 gpu --
title "4/7 Graphics"
detected=$("${DETECT[@]}" --shell 2>>"$LOG") || die "GPU detection failed (see $LOG)"
PROFILE=none; NVIDIA_OPEN=-; SUPPORT=none; GPU="unknown"; REASON=""; VRAM_MIB=""
eval "$detected"   # PROFILE NVIDIA_OPEN SUPPORT GPU REASON VRAM_MIB (shell-quoted by the detector)
note "Detected: $GPU"
note "Suggested profile: ${B}$PROFILE${N} ($SUPPORT) — $REASON"
[[ "$SUPPORT" == unsupported ]] && warn "This GPU is not a supported Freutigo GPU; the desktop may lack acceleration."
echo "  Profiles: $PROFILES"
ask GPU_PROFILE "Graphics profile ('auto' = suggested)" "auto" is_profile
[[ "$GPU_PROFILE" == auto ]] && GPU_PROFILE=$PROFILE
NVIDIA_OPEN_SETTING=""
if [[ "$GPU_PROFILE" == nvidia-modern && "$NVIDIA_OPEN" == false ]]; then
  NVIDIA_OPEN_SETTING="false"
fi
LICENSE_OK=no
if [[ "$GPU_PROFILE" == nvidia-legacy-470 ]]; then
  warn "nvidia-legacy-470 is EXPERIMENTAL, X11-only and unmaintained upstream (docs/HARDWARE.md)."
  echo "  It requires accepting NVIDIA's licence:"
  echo "  https://www.nvidia.com/content/DriverDownloads/licence.php?lang=us"
  ask_yn ACCEPT_NVIDIA_LICENSE "Do you accept the NVIDIA licence?" "no"
  LICENSE_OK=$ACCEPT_NVIDIA_LICENSE
  [[ "$LICENSE_OK" == yes ]] || die "licence not accepted; choose nvidia-kepler-oss instead"
fi

ask_yn DESKTOP "Install the Aero desktop? ('no' = text console only)" "yes"
if [[ "$DESKTOP" == yes ]]; then
  [[ "$GPU_PROFILE" == none ]] && die "the desktop needs a graphics profile other than 'none'"
  # Cards with less than 2 GiB VRAM (e.g. many R7 250 / HD 7750 boards with
  # 1 GiB) default to Aero Lite; the user can still choose full Aero.
  mode_default=aero
  if [[ "$VRAM_MIB" =~ ^[0-9]+$ ]] && (( VRAM_MIB < 2048 )); then
    mode_default=aero-lite
    note "Graphics memory: ${VRAM_MIB} MiB (< 2 GiB) — Aero Lite suggested"
  fi
  ask DESKTOP_MODE "Desktop mode: aero (full effects) or aero-lite (older/low-VRAM GPUs)" "$mode_default" is_mode
  ask_yn STEAM "Install Steam (unfree; client is downloaded from Valve on first start)?" "yes"
else
  DESKTOP_MODE=aero; STEAM=no
fi

# ---------------------------------------------------------------- 5 disk --
title "5/7 Disk"
if [[ -d /sys/firmware/efi ]]; then FW_DETECTED=uefi; else FW_DETECTED=bios; fi
ask FIRMWARE "Firmware type (detected: $FW_DETECTED)" "auto" is_firmware
[[ "$FIRMWARE" == auto ]] && FIRMWARE=$FW_DETECTED
if [[ "$FIRMWARE" == uefi && "$FW_DETECTED" == bios && $DRY_RUN -eq 0 ]]; then
  die "UEFI install requested but this machine booted the installer in legacy BIOS mode"
fi

live_disk=""
if [[ $DRY_RUN -eq 0 ]]; then
  src=$(findmnt -no SOURCE /iso 2>/dev/null || true)
  [[ -n "$src" ]] && live_disk=$(lsblk -no PKNAME "$src" 2>/dev/null | head -1 || true)
  echo "  Disks:"
  lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF=="disk"' | while read -r l; do
    name=${l%% *}
    if [[ -n "$live_disk" && "$name" == "/dev/$live_disk" ]]; then echo "    $l   (installer media — not selectable)"; else echo "    $l"; fi
  done
fi
echo "  Modes:  erase   = erase ONE WHOLE DISK and install Freutigo on it"
echo "          mounted = use partitions you already created and mounted at $ROOT"
echo "                    (dual boot / custom layout; nothing is formatted)"
ask DISK_MODE "Disk mode" "erase" is_diskmode

BIOS_DEVICE=""
if [[ "$DISK_MODE" == erase ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    DISK=${ANS[DISK]-/dev/sdX}
  else
    ask DISK "Disk to ERASE (full path, e.g. /dev/sda)" "" is_disk
    [[ -n "$live_disk" && "$DISK" == "/dev/$live_disk" ]] && die "$DISK is the installer media"
  fi
  echo
  echo "  ${R}${B}ALL DATA ON $DISK WILL BE DESTROYED.${N}"
  [[ $DRY_RUN -eq 0 ]] && lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK" | sed 's/^/    /'
  if [[ $UNATTENDED -eq 1 ]]; then
    [[ "${ANS[CONFIRM_ERASE]-}" == "$DISK" ]] || die "unattended erase requires CONFIRM_ERASE=$DISK"
  else
    read -r -p "  Type the disk path ($DISK) to confirm: " c1
    [[ "$c1" == "$DISK" ]] || die "confirmation did not match; nothing was changed"
  fi
  disk_id=""
  for l in /dev/disk/by-id/*; do
    [[ "$l" == *-part* ]] && continue
    [[ "$(readlink -f "$l")" == "$(readlink -f "$DISK")" ]] && { disk_id=$l; break; }
  done
  BIOS_DEVICE=${disk_id:-$DISK}
else
  if [[ $DRY_RUN -eq 0 ]]; then
    mountpoint -q "$ROOT" || die "$ROOT is not mounted. Mount your root partition at $ROOT (and the EFI partition at $ROOT/boot for UEFI)."
    if [[ "$FIRMWARE" == uefi ]]; then
      [[ "$(findmnt -no FSTYPE "$ROOT/boot" 2>/dev/null)" == vfat ]] || die "UEFI: mount the EFI system partition (vfat) at $ROOT/boot"
    else
      ask BIOS_DEVICE "BIOS: whole disk to install GRUB to (e.g. /dev/sda)" "" is_disk
    fi
  else
    BIOS_DEVICE=${ANS[BIOS_DEVICE]-/dev/sdX}
  fi
fi

ask REBOOT "When finished: reboot, poweroff, or no" "yes" is_reboot

# ------------------------------------------------------------- 6 summary --
title "6/7 Summary"
cat <<EOF
  Language/keyboard/time zone : $LOCALE / $KEYMAP${XKB:+ (desktop: $XKB)} / $TIMEZONE
  Computer name / user        : $HOSTNAME / $USERNAME ($FULLNAME)
  Graphics profile            : $GPU_PROFILE${NVIDIA_OPEN_SETTING:+ (closed kernel module)}${VRAM_MIB:+, ${VRAM_MIB} MiB VRAM}
  Desktop                     : $DESKTOP$([[ $DESKTOP == yes ]] && echo " ($DESKTOP_MODE)"), Steam: $STEAM
  Firmware / bootloader       : $FIRMWARE / $([[ $FIRMWARE == uefi ]] && echo systemd-boot || echo "GRUB on $BIOS_DEVICE")
  Disk                        : $([[ $DISK_MODE == erase ]] && echo "ERASE $DISK" || echo "use partitions mounted at $ROOT")
EOF
if [[ $UNATTENDED -eq 0 ]]; then
  read -r -p "  Start installation? Type 'install' to continue: " go
  [[ "$go" == install ]] || die "aborted by user; nothing was changed"
fi

# ------------------------------------------------------------- 7 install --
title "7/7 Installing"

if [[ "$DISK_MODE" == erase ]]; then
  note "Partitioning $DISK"
  umount -R "$ROOT" 2>/dev/null || true
  run wipefs -a "$DISK"
  if [[ "$FIRMWARE" == uefi ]]; then
    run parted -s "$DISK" -- mklabel gpt \
      mkpart FREUTIGO_EFI fat32 1MiB 1GiB set 1 esp on \
      mkpart FREUTIGO_ROOT ext4 1GiB 100%
  else
    # GPT + BIOS boot partition for GRUB (works on disks > 2 TiB too).
    run parted -s "$DISK" -- mklabel gpt \
      mkpart biosboot 1MiB 2MiB set 1 bios_grub on \
      mkpart FREUTIGO_ROOT ext4 2MiB 100%
  fi
  run udevadm settle
  run sleep 1
  ROOT_PART=/dev/disk/by-partlabel/FREUTIGO_ROOT
  note "Formatting"
  run mkfs.ext4 -F -q -L FREUTIGO_ROOT "$ROOT_PART"
  if [[ "$FIRMWARE" == uefi ]]; then
    run mkfs.fat -F 32 -n FREUTIGOEFI /dev/disk/by-partlabel/FREUTIGO_EFI
  fi
  run udevadm settle
  run mkdir -p "$ROOT"
  run mount /dev/disk/by-label/FREUTIGO_ROOT "$ROOT"
  if [[ "$FIRMWARE" == uefi ]]; then
    run mkdir -p "$ROOT/boot"
    run mount -o umask=077 /dev/disk/by-label/FREUTIGOEFI "$ROOT/boot"
  fi
fi

CONF=${TARGET_OVERRIDE:-$ROOT/etc/freutigo}
note "Writing configuration to $CONF"
if [[ $DRY_RUN -eq 1 && -n "$TARGET_OVERRIDE" ]]; then
  rm -rf "$CONF"; mkdir -p "$(dirname "$CONF")"; cp -rL "$SOURCE" "$CONF"; chmod -R u+w "$CONF"
else
  run mkdir -p "$(dirname "$CONF")"
  run cp -rL "$SOURCE" "$CONF"
  run chmod -R u+w "$CONF"
fi
rm -rf "$CONF/.git" "$CONF/hosts/local"
mkdir -p "$CONF/hosts/local"

# Hardware configuration: detected kernel modules etc. from nixos-generate-config.
# When this installer formatted the disk, file systems are referenced by the
# labels it created (stable, readable); otherwise the generated UUIDs are used.
if [[ $DRY_RUN -eq 1 ]]; then
  cat > "$CONF/hosts/local/hardware-configuration.nix" <<'EOF'
# dry-run placeholder (nixos-generate-config not executed)
{ ... }:
{
  imports = [ ../common/placeholder-hardware.nix ];
}
EOF
elif [[ "$DISK_MODE" == erase ]]; then
  nixos-generate-config --root "$ROOT" --no-filesystems --show-hardware-config \
    > "$CONF/hosts/local/hardware-configuration.nix" 2>>"$LOG"
  {
    echo "  fileSystems.\"/\" = { device = \"/dev/disk/by-label/FREUTIGO_ROOT\"; fsType = \"ext4\"; };"
    if [[ "$FIRMWARE" == uefi ]]; then
      echo "  fileSystems.\"/boot\" = { device = \"/dev/disk/by-label/FREUTIGOEFI\"; fsType = \"vfat\"; options = [ \"fmask=0077\" \"dmask=0077\" ]; };"
    fi
  } > "$CONF/hosts/local/filesystems.fragment"
  # Insert the file systems before the final closing brace.
  hw="$CONF/hosts/local/hardware-configuration.nix"
  [[ "$(tail -n 1 "$hw")" == "}" ]] || die "unexpected nixos-generate-config output format"
  sed -i '$ d' "$hw"
  cat "$CONF/hosts/local/filesystems.fragment" >> "$hw"
  echo "}" >> "$hw"
  rm -f "$CONF/hosts/local/filesystems.fragment"
else
  nixos-generate-config --root "$ROOT" --show-hardware-config \
    > "$CONF/hosts/local/hardware-configuration.nix" 2>>"$LOG"
fi

{
  echo "# Generated by freutigo-install on $(date -u +%Y-%m-%dT%H:%M:%SZ). Safe to edit."
  echo "# Apply changes with:  sudo nixos-rebuild boot --flake /etc/freutigo#local"
  echo "{ ... }:"
  echo "{"
  echo "  imports = ["
  [[ "$DESKTOP" == yes ]] && echo "    ../common/desktop.nix"
  echo "    ./hardware-configuration.nix"
  echo "  ];"
  echo
  echo "  networking.hostName = $(nix_str "$HOSTNAME");"
  echo "  time.timeZone = $(nix_str "$TIMEZONE");"
  echo "  i18n.defaultLocale = $(nix_str "$LOCALE");"
  echo "  console.keyMap = $(nix_str "$KEYMAP");"
  [[ -n "$XKB" ]] && echo "  services.xserver.xkb.layout = $(nix_str "$XKB");"
  echo
  echo "  freutigo.user.name = $(nix_str "$USERNAME");"
  echo "  freutigo.user.description = $(nix_str "$FULLNAME");"
  echo
  echo "  freutigo.hardware.gpuProfile = $(nix_str "$GPU_PROFILE");"
  [[ -n "$NVIDIA_OPEN_SETTING" ]] && echo "  freutigo.hardware.nvidia.openKernelModule = false;"
  if [[ "$GPU_PROFILE" == nvidia-legacy-470 ]]; then
    echo "  # Accepted interactively during installation by the machine owner."
    echo "  freutigo.hardware.nvidia.acceptLegacyLicense = true;"
    echo "  freutigo.desktop.session = \"x11\";"
  fi
  if [[ "$DESKTOP" == yes ]]; then
    echo "  freutigo.desktop.mode = $(nix_str "$DESKTOP_MODE");"
    echo "  freutigo.gaming.steam.enable = $([[ $STEAM == yes ]] && echo true || echo false);"
  fi
  echo
  echo "  freutigo.boot.mode = $(nix_str "$FIRMWARE");"
  [[ "$FIRMWARE" == bios ]] && echo "  freutigo.boot.biosDevice = $(nix_str "$BIOS_DEVICE");"
  if [[ "${ANS[E2E_SERIAL_MARKER]-no}" == yes ]]; then
    echo
    echo "  # Automated end-to-end test hook (scripts/e2e-install-test.sh)."
    echo "  freutigo.testing.serialBootMarker = true;"
  fi
  echo "}"
} > "$CONF/hosts/local/default.nix"
log "generated hosts/local/default.nix:"; cat "$CONF/hosts/local/default.nix" >> "$LOG"

# Flakes only see git-tracked files.
(
  cd "$CONF"
  git init -q
  git add -A
  git -c user.name="freutigo-install" -c user.email="install@localhost" \
    commit -q -m "Installed configuration ($HOSTNAME)"
) >> "$LOG" 2>&1 || die "git setup of $CONF failed (see $LOG)"

if [[ $DRY_RUN -eq 1 ]]; then
  note "${G}Dry run complete.${N} Configuration: $CONF (host 'local')"
  exit 0
fi

note "Downloading and installing the system. This takes a while (several GB for the desktop)."
note "Progress is logged to $LOG"
# VERBOSE=yes (answers file) streams the complete nixos-install output.
progress_filter='^(copying path|building |error|installing the boot loader|installation finished)'
[[ "${ANS[VERBOSE]-no}" == yes ]] && progress_filter='.'
set +e
nixos-install --root "$ROOT" --flake "$CONF#local" --no-root-passwd --no-channel-copy < /dev/null 2>&1 |
  tee -a "$LOG" |
  grep --line-buffered -E "$progress_filter" |
  sed -u 's/^/    /'
rc=${PIPESTATUS[0]}
set -e
[[ $rc -eq 0 ]] || die "nixos-install failed (exit $rc). Only the new partitions were changed; see $LOG"

note "Setting the password for $USERNAME"
printf '%s:%s\n' "$USERNAME" "$PASSWORD" | nixos-enter --root "$ROOT" -c 'chpasswd' >> "$LOG" 2>&1 \
  || die "could not set the password; after reboot use the text-console entry or rerun: nixos-enter --root $ROOT -c 'passwd $USERNAME'"
unset PASSWORD p2

cp "$LOG" "$ROOT/var/log/freutigo-install.log" 2>/dev/null || true
note "${G}${B}Installation complete.${N}"
note "Configuration: /etc/freutigo (host 'local'). Recovery: docs/RECOVERY.md"

[[ $NO_REBOOT -eq 1 ]] && REBOOT=no
case "$REBOOT" in
  yes) note "Rebooting..."; sync; umount -R "$ROOT" || true; systemctl reboot ;;
  poweroff) note "Powering off..."; sync; umount -R "$ROOT" || true; systemctl poweroff ;;
  *) note "Remove the installer media and reboot when ready." ;;
esac
