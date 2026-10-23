# nvme-power-tune

NVMe and CPU power tuning for an MSI Cyborg 15 B13WFKG (i7-13620H, RTX 5060 Laptop)
running Ubuntu 26.04, with a **Micron 2500 512GB** (MTFDKBA512QGN, DRAM-less QLC)
behind Intel VMD, LUKS2 → LVM → ext4.

- **On AC:** NVMe APST is turned off and the power profile is set to `performance`.
- **On battery:** the kernel's original APST table is restored and the profile is set to `balanced`.
- **Always:** readahead on the root logical volume is 1 MiB.
- **CPU power limits:**
  - On AC: 45 W sustained / 65 W boost (stock is 20/25 W).
  - While a game runs (via GameMode) or on battery: stock 20/25 W.
  - thermald runs without `--adaptive`, so it keeps temperature protection but stops pinning the CPU at 20 W.

It runs at boot, whenever you plug in or unplug, and after resume.

## Install / remove

```bash
./install.sh          # LV=vg/lv ./install.sh  to target another volume
./uninstall.sh
journalctl -t nvme-power-tune     # see what was applied
```

To stop it from changing the power profile, set `SWITCH_PROFILE=0` in
`/usr/local/sbin/nvme-power-tune`.

To change the CPU limits, edit `/etc/default/cpu-power-tune`, then run
`sudo cpu-power-tune`.

For games, set the Steam launch option to `gamemoderun %command%`. The installer
writes `~/.config/gamemode.ini`, and it allows exactly two commands without a
password (`/etc/sudoers.d/cpu-power-tune`).

## Findings

All raw-device tests were read-only (`fio --readonly`). Every temporary change was reverted afterwards.

| Area | Result |
|---|---|
| PCIe | 16 GT/s x4. Reading a nearly empty region gives **6,748 MiB/s**, so the link, VMD and controller are fine. |
| Real data, sequential 1M | ~2.2–2.4 GiB/s. The limit is the 512GB QLC flash (few NAND dies). Rated 6,600 MB/s is best-case. |
| LUKS (aes-xts-512, VAES) | ~0% cost. Raw and decrypted reads match. `no_read/write_workqueue` already set. |
| LVM + ext4 | ~0–5% |
| Thermal | 43 °C idle, 57 °C after sustained reads. Zero T1/T2 throttle events. |
| HMB | Enabled, 64 MB |
| io_uring vs libaio, QD, scheduler | No meaningful difference. `none` kept. |
| ASPM | Controlled by the BIOS under VMD. Runtime policy change is refused. |

## Experiments (one change at a time)

| Change | Effect | Kept |
|---|---|---|
| APST off | 4K read after idle: 5–16 ms avg with 30–38 ms spikes → ~1.4 ms steady | on AC |
| Readahead 128 → 1024 KB | Buffered seq ~1.1 → ~2.0–2.4 GiB/s | yes |
| PS3-only APST table | ~2.3 ms avg, ~14 ms max after idle | optional (see below) |
| CPU latency QoS 0 µs | No gain; lower throughput | no |
| mq-deadline vs none | Within noise | no |

### Optional battery compromise

Booting with `nvme_core.default_ps_max_latency_us=5500` keeps the shallow PS3
state on battery but drops the deep PS4 state (30 ms exit latency). Test it once
by pressing `e` at the GRUB menu before adding it to `/etc/default/grub`.

## Benchmark

`tools/bench.sh LABEL` reports: sequential 1M read, 4K QD1 latency, 4K latency
after 250 ms idle, and buffered read speed. It only reads.

## CPU / GPU

### Findings

- **CPU:** the BIOS DPTF tables (enforced by `thermald --adaptive`) cap the MMIO RAPL
  limits at **PL1 20 W / PL2 25 W**. The i7-13620H is rated 45 W base and 115 W max turbo.
  Under all-core load the CPU sat at ~1.85 GHz and 58 °C: power-capped, not thermally limited.
- **GPU:** the RTX 5060 Laptop runs at a 45 W base plus 10 W Dynamic Boost (`nvidia-powerd`),
  so the enforced limit is **55 W, its maximum**. Under load it reached 95% utilization,
  ~52 W and 68 °C, limited only by the power cap. There is nothing safe to unlock.
- **Shared budget:** the CPU and GPU share one power and cooling budget. The more power
  the CPU is allowed, the less the GPU gets.

### Experiments

CPU only: stress-ng matrixprod, 16 threads for 60 s.

| Setting | Multi | Single | All-core clock | Max temp |
|---|---|---|---|---|
| Stock 20/25 W (thermald adaptive) | 11,125–11,365 | 3,031–3,182 | ~1.85 GHz | 58 °C |
| 45/65 W, thermald adaptive | reverted to 20 W in ~10 s | | | |
| thermald stopped, stock limits | 11,365 (no change) | | | |
| 45/65 W, thermald stopped | 18,700 | 3,462 | 3.3 GHz | 74 °C |
| 45/65 W, thermald non-adaptive | 19,321–20,908 | 3,438–3,455 | 3.3–3.8 GHz | 83 °C |
| 55/80 W | 21,909 | 3,464 | 3.5–4.1 GHz | **93 °C** (too close to 95 °C TCC) |

Gaming-like load: glmark2 terrain at 2560×1440 on the RTX 5060, plus 8 CPU threads.

| CPU limit | GPU power | GPU clock | CPU 8T |
|---|---|---|---|
| Stock 20/25 W | 49.5 W | 1,970–2,180 MHz | 10,915–11,548 |
| 25/35 W | 43.8 W | 2,027 MHz | 14,320 |
| 30/45 W | 38.6 W | 1,691 MHz | 16,125 |
| 45/65 W | 34.7 W | 1,464 MHz | 17,121–18,708 |
| **Installed, under GameMode** | **49.3 W** | 1,990 MHz | 9,650 |

GPU FPS in this synthetic test varied ±10% between identical runs because of heat soak.
GPU power is the reliable signal.
