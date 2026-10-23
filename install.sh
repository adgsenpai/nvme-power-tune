#!/bin/sh
# Install nvme-power-tune (AC: APST off + performance; battery: kernel APST + balanced)
# and set 1 MiB readahead on the root LV.
set -e
cd "$(dirname "$0")/files"
sudo install -m 755 nvme-power-tune /usr/local/sbin/nvme-power-tune
sudo install -m 644 99-nvme-power-tune.rules /etc/udev/rules.d/99-nvme-power-tune.rules
sudo install -m 644 nvme-power-tune.service /etc/systemd/system/nvme-power-tune.service
sudo install -m 755 nvme-power-tune.sleep /usr/lib/systemd/system-sleep/nvme-power-tune
sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl enable --now nvme-power-tune.service
LV=${LV:-ubuntu-vg/ubuntu-lv}
sudo lvchange --readahead 2048 "$LV" || true   # 2048 sectors = 1 MiB
journalctl -t nvme-power-tune -n 1 --no-pager
