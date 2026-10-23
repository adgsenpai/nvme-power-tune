# nvme-power-tune

NVMe tuning for an MSI Cyborg 15 B13WFKG (i7-13620H) running Ubuntu 26.04, with a
**Micron 2500 512GB** (MTFDKBA512QGN, DRAM-less QLC) behind Intel VMD,
LUKS2 → LVM → ext4.

- **On AC:** NVMe APST is turned off and the power profile is set to `performance`.
- **On battery:** the kernel's original APST table is restored and the profile is set to `balanced`.
- **Always:** readahead on the root logical volume is 1 MiB.

It runs at boot, whenever you plug in or unplug, and after resume.

CPU/GPU tuning for the same laptop lives in a separate repo:
[cyborg15-cpu-gpu-tune](https://github.com/adgsenpai/cyborg15-cpu-gpu-tune).

## Install / remove

```bash
./install.sh          # LV=vg/lv ./install.sh  to target another volume
./uninstall.sh
journalctl -t nvme-power-tune     # see what was applied
```

To stop it from changing the power profile, set `SWITCH_PROFILE=0` in
`/usr/local/sbin/nvme-power-tune`.

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

## Benchmark: stock vs tuned (back-to-back, on AC)

| Test | Stock | Tuned | Gain |
|---|---|---|---|
| Buffered reads (game loading, file copies) | 1,062 MiB/s | **2,233 MiB/s** | **2.1×** |
| First 4K read after idle, average | 7.0 ms | **1.6 ms** | **4.5×** |
| First 4K read after idle, worst case | 33.2 ms | **1.8 ms** | **18×** |
| Raw sequential 1M (direct) | 2,183 MiB/s | 2,270 MiB/s | flash-limited |
