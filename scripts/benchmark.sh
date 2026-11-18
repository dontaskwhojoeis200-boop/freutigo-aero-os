#!/usr/bin/env bash
# freutigo-benchmark — idle resource measurement (sections 6.1, XIV)
#
# Method (section 6.1):
#   1. boot, 2. log into the desktop, 3. let startup settle (default 10 min),
#   4. no user applications running, 5. record system + per-process usage.
#
# Accounting:
#   - "Used" = MemTotal - MemAvailable (excludes reclaimable cache).
#   - Process memory = PSS from /proc/PID/smaps_rollup (shared pages split
#     proportionally, so nothing is double-counted). Run as root to see
#     every process.
#   - Processes are grouped by cgroup: user.slice = desktop session,
#     system.slice = background services, everything else = other.
#
# Usage: freutigo-benchmark [--settle SEC] [--interval SEC] [--label NAME]
#                           [--out DIR] [--no-file]
set -euo pipefail

SETTLE=600
INTERVAL=60
LABEL="$(cat /etc/freutigo/desktop-mode 2>/dev/null || echo unknown)"
OUTDIR="${PWD}/benchmarks/results"
WRITE_FILE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settle) SETTLE="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --out) OUTDIR="$2"; shift 2 ;;
    --no-file) WRITE_FILE=0; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "warning: not root — PSS of other users' and system processes will be missing." >&2
  echo "         re-run with sudo for complete accounting." >&2
fi

if (( SETTLE > 0 )); then
  up=$(awk '{print int($1)}' /proc/uptime)
  echo "Uptime ${up}s. Waiting ${SETTLE}s for startup activity to settle (Ctrl-C to abort)..." >&2
  sleep "$SETTLE"
fi

kib_to_mib() { awk -v k="$1" 'BEGIN { printf "%.1f", k / 1024 }'; }
meminfo() { awk -v k="$1:" '$1 == k { print $2 }' /proc/meminfo; }

# ---- CPU + disk sampling over the interval ---------------------------------
read_cpu() { awk '/^cpu / { idle = $5 + $6; tot = 0; for (i = 2; i <= NF; i++) tot += $i; print idle, tot }' /proc/stat; }
read_disk() {
  # sectors read / written for whole physical/virtual disks
  awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|hd[a-z]+|mmcblk[0-9]+)$/ { r += $6; w += $10 } END { print r + 0, w + 0 }' /proc/diskstats
}
snapshot_proc_cpu() {
  for p in /proc/[0-9]*; do
    [[ -r "$p/stat" ]] || continue
    # field 14 utime, 15 stime (after the parenthesised comm)
    awk -v pid="${p##*/}" '{ sub(/^.*\) /, ""); print pid, $12 + $13 }' "$p/stat" 2>/dev/null || true
  done
}

echo "Sampling CPU and disk activity for ${INTERVAL}s..." >&2
read -r idle0 tot0 < <(read_cpu)
read -r dr0 dw0 < <(read_disk)
proc0=$(snapshot_proc_cpu)
sleep "$INTERVAL"
read -r idle1 tot1 < <(read_cpu)
read -r dr1 dw1 < <(read_disk)
proc1=$(snapshot_proc_cpu)

cpu_busy=$(awk -v i0="$idle0" -v t0="$tot0" -v i1="$idle1" -v t1="$tot1" \
  'BEGIN { dt = t1 - t0; if (dt <= 0) { print "n/a"; exit } printf "%.2f", 100 * (1 - (i1 - i0) / dt) }')
disk_read_kib=$(( (dr1 - dr0) / 2 ))
disk_write_kib=$(( (dw1 - dw0) / 2 ))
hz=$(getconf CLK_TCK)
top_cpu=$(join <(sort -k1,1 <<<"$proc0") <(sort -k1,1 <<<"$proc1") 2>/dev/null |
  awk -v hz="$hz" -v iv="$INTERVAL" '{ d = $3 - $2; if (d > 0) printf "%.2f %s\n", 100 * d / hz / iv, $1 }' |
  sort -rn | head -8 |
  while read -r pct pid; do
    comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "?")
    echo "| $comm | $pid | $pct |"
  done)

# ---- Memory ------------------------------------------------------------------
total=$(meminfo MemTotal); avail=$(meminfo MemAvailable); free=$(meminfo MemFree)
buffers=$(meminfo Buffers); cached=$(meminfo Cached); srecl=$(meminfo SReclaimable)
shmem=$(meminfo Shmem); swap_t=$(meminfo SwapTotal); swap_f=$(meminfo SwapFree)
slab_u=$(meminfo SUnreclaim); kstack=$(meminfo KernelStack); ptables=$(meminfo PageTables)
used=$(( total - avail ))
cache=$(( buffers + cached + srecl ))
kernel_est=$(( slab_u + kstack + ptables ))

# True if PID is this script or one of its descendants.
is_own_process() {
  local p=$1 depth=0
  while [[ "$p" -gt 1 && $depth -lt 32 ]]; do
    [[ "$p" == "$$" ]] && return 0
    p=$(awk '/^PPid:/ { print $2 }' "/proc/$p/status" 2>/dev/null || echo 0)
    [[ -n "$p" ]] || return 1
    depth=$((depth + 1))
  done
  return 1
}

# PSS per process, grouped by cgroup
pss_table=$(
  for p in /proc/[0-9]*; do
    pid=${p##*/}
    # Exclude this script and its own helper processes from the accounting.
    is_own_process "$pid" && continue
    pss=$(awk '/^Pss:/ { print $2; exit }' "$p/smaps_rollup" 2>/dev/null) || continue
    [[ -n "$pss" ]] || continue
    cg=$(head -c 512 "$p/cgroup" 2>/dev/null | tr '\n' ' ')
    case "$cg" in
      *user.slice*) grp=desktop ;;
      *system.slice*) grp=services ;;
      *) grp=other ;;
    esac
    comm=$(cat "$p/comm" 2>/dev/null || echo "?")
    echo "$pss $grp $pid $comm"
  done | sort -rn
)
sum_group() { awk -v g="$1" '$2 == g { s += $1 } END { print s + 0 }' <<<"$pss_table"; }
pss_desktop=$(sum_group desktop); pss_services=$(sum_group services); pss_other=$(sum_group other)
nprocs=$(grep -c . <<<"$pss_table" || true)

# GPU memory (amdgpu reports exact values)
gpu_mem="not measurable on this driver"
for d in /sys/class/drm/card[0-9]*/device; do
  if [[ -r "$d/mem_info_vram_used" ]]; then
    gpu_mem="VRAM $(( $(cat "$d/mem_info_vram_used") / 1048576 )) / $(( $(cat "$d/mem_info_vram_total") / 1048576 )) MiB, GTT $(( $(cat "$d/mem_info_gtt_used" 2>/dev/null || echo 0) / 1048576 )) MiB"
    break
  fi
done

boot_time="n/a"
if command -v systemd-analyze >/dev/null 2>&1; then
  boot_time=$(systemd-analyze time 2>/dev/null | head -1 || echo "n/a")
fi

# ---- Report --------------------------------------------------------------------
stamp=$(date -u +%Y%m%dT%H%M%SZ)
host=$(cat /proc/sys/kernel/hostname)
cpu_model=$(awk -F: '/^model name/ { gsub(/^ +/, "", $2); print $2; exit }' /proc/cpuinfo)

report=$(cat <<EOF
# Freutigo idle benchmark — ${host} — ${stamp}

| Field | Value |
|---|---|
| Label / desktop mode | ${LABEL} |
| Freutigo version | $(cat /etc/freutigo/version 2>/dev/null || echo n/a) |
| GPU profile | $(cat /etc/freutigo/gpu-profile 2>/dev/null || echo n/a) |
| Session type | ${XDG_SESSION_TYPE:-unknown} |
| Kernel | $(uname -r) |
| CPU | ${cpu_model} |
| Uptime at measurement | $(awk '{ print int($1) }' /proc/uptime) s (settle ${SETTLE} s) |
| Boot time | ${boot_time} |
| Ran as root | $([[ $EUID -eq 0 ]] && echo yes || echo "no — process totals incomplete") |

## Memory (MiB)

| Metric | MiB |
|---|---|
| Total physical | $(kib_to_mib "$total") |
| Available | $(kib_to_mib "$avail") |
| **Used (Total − Available)** | **$(kib_to_mib "$used")** |
| Free (never used) | $(kib_to_mib "$free") |
| Reclaimable cache (Buffers+Cached+SReclaimable) | $(kib_to_mib "$cache") |
| Shared memory (Shmem, part of Cached) | $(kib_to_mib "$shmem") |
| Swap used | $(kib_to_mib $(( swap_t - swap_f ))) |
| Kernel (SUnreclaim+KernelStack+PageTables, estimate) | $(kib_to_mib "$kernel_est") |
| Desktop session processes (PSS, user.slice) | $(kib_to_mib "$pss_desktop") |
| Background services (PSS, system.slice) | $(kib_to_mib "$pss_services") |
| Other processes (PSS) | $(kib_to_mib "$pss_other") |
| GPU memory | ${gpu_mem} |

Targets (section 6.1): used < 1024 MiB required; 600–800 preferred; Lite 500–700.

## Activity over ${INTERVAL} s

| Metric | Value |
|---|---|
| CPU busy (all cores) | ${cpu_busy} % |
| Disk read | ${disk_read_kib} KiB |
| Disk written | ${disk_write_kib} KiB |

### Top CPU consumers during interval

| Process | PID | CPU % (of one core) |
|---|---|---|
${top_cpu:-| (none measurable) | | |}

## Top 15 processes by PSS (${nprocs} processes readable)

| PSS MiB | Group | PID | Process |
|---|---|---|---|
$(head -15 <<<"$pss_table" | awk '{ printf "| %.1f | %s | %s | %s |\n", $1 / 1024, $2, $3, $4 }')
EOF
)

echo "$report"
if [[ $WRITE_FILE -eq 1 ]]; then
  mkdir -p "$OUTDIR"
  file="$OUTDIR/${host}-${LABEL}-${stamp}.md"
  echo "$report" > "$file"
  echo >&2; echo "Saved: $file" >&2
fi
