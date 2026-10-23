#!/bin/bash
# Read-only NVMe bench (needs ~/ssd-benchmark/ssdtest.0.0 from an earlier fio run).
# Usage: bench.sh LABEL
L=$1; F=$HOME/ssd-benchmark/ssdtest.0.0; D=/dev/mapper/dm_crypt-0
t(){ sudo fio --name=x --readonly --direct=1 --ioengine=io_uring --output-format=terse --terse-version=3 "$@" 2>/dev/null; }
seq=$(t --filename=$D --rw=read --bs=1M --iodepth=32 --offset=100G --size=16G --runtime=10 --time_based | awk -F';' '{printf "%.0f", $7/1024}')
r1=$(t --filename=$D --rw=randread --bs=4k --iodepth=1 --size=400G --runtime=10 --time_based | awk -F';' '{split($30,p,"="); printf "%.0f/%s", $16, p[2]}')
idle=$(t --filename=$D --rw=randread --bs=4k --iodepth=1 --size=400G --thinktime=250000 --runtime=12 --time_based | awk -F';' '{printf "%.0f/%.0f", $16, $15}')
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
buf=$(sudo fio --name=x --readonly --direct=0 --ioengine=psync --filename=$F --rw=read --bs=128k --size=8G --output-format=terse --terse-version=3 2>/dev/null | awk -F';' '{printf "%.0f", $7/1024}')
temp=$(sudo nvme smart-log /dev/nvme0 | awk '/^temperature/{print $3}')
printf '%-22s seq1M=%5s MiB/s | 4kQD1 mean/p99=%s us | after-idle mean/max=%s us | buffered=%5s MiB/s | %sC\n' "$L" "$seq" "$r1" "$idle" "$buf" "$temp"
