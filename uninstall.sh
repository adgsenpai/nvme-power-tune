#!/bin/sh
# Remove nvme-power-tune and return readahead to LVM's default.
set -e
sudo systemctl disable --now nvme-power-tune.service 2>/dev/null || true
sudo rm -f /usr/local/sbin/nvme-power-tune /etc/udev/rules.d/99-nvme-power-tune.rules \
    /etc/systemd/system/nvme-power-tune.service /usr/lib/systemd/system-sleep/nvme-power-tune
sudo udevadm control --reload
sudo systemctl daemon-reload
LV=${LV:-ubuntu-vg/ubuntu-lv}
sudo lvchange --readahead auto "$LV"
echo "Removed. APST returns to the kernel default at next reboot."
