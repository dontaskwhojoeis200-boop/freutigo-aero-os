# Performance

> **No measurements exist yet.** Every value below is **PENDING**. Numbers are
> recorded only from real runs of `freutigo-benchmark` on identified hardware
> (Rule 4: never fabricate results).

## Method

Idle memory (section 6.1), run as root on the installed system:

```sh
# after login, with no applications open; waits 10 min, samples 60 s
sudo freutigo-benchmark --label aero
# switch to Aero Lite (freutigo.desktop.mode = "aero-lite"), reboot, repeat
sudo freutigo-benchmark --label aero-lite
```

The tool records: total / available / used (Total − MemAvailable) memory,
reclaimable cache, swap, kernel estimate, **PSS** per process grouped into
desktop session (user.slice) vs. background services (system.slice), amdgpu
VRAM/GTT, CPU busy %, top CPU consumers, disk read/write over the interval,
and `systemd-analyze` boot time. Results go to `benchmarks/results/`.

Comparisons must use identical CPU, RAM, storage, resolution and workload.
Gaming numbers (average FPS, 1 % and 0.1 % lows) are reported only with
reliable frame-time capture (MangoHud logging, planned for F4).

## Targets vs. results

| Metric | Target | R9 270 | HD 7850 | GTX 660 (nouveau) | GTX 660 (470) |
|---|---|---|---|---|---|
| Idle RAM used, Aero | < 1024 MiB (600–800 preferred) | PENDING | PENDING | PENDING | PENDING |
| Idle RAM used, Aero Lite | 500–700 MiB | PENDING | PENDING | PENDING | PENDING |
| Idle CPU busy | minimal | PENDING | PENDING | PENDING | PENDING |
| Background disk I/O (60 s) | minimal | PENDING | PENDING | PENDING | PENDING |
| Cold boot to desktop (HDD) | — | PENDING | PENDING | PENDING | PENDING |
| Desktop frame pacing @1080p | smooth 60 Hz | PENDING | PENDING | PENDING | PENDING |
| Browser startup | responsive | PENDING | PENDING | PENDING | PENDING |
| Steam startup | functional | PENDING | PENDING | PENDING | PENDING |
| Vulkan (vkcube / game) | verified HW accel | PENDING | PENDING | PENDING | PENDING |

## Tool validation (F0)

`scripts/benchmark.sh` was executed in the F0 build container (not a Freutigo
system, no GPU) to validate the script itself: it produced a complete report,
correct /proc/meminfo arithmetic, PSS grouping, CPU and disk sampling, and
excluded its own helper processes. That run says nothing about Freutigo
performance and is not recorded as a result.
