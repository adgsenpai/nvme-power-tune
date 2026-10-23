#!/bin/sh
# Remove NVMe + CPU power tuning and return to stock behaviour.
set -e
U=${SUDO_USER:-$(id -un)}
H=$(getent passwd "$U" | cut -d: -f6)
sudo systemctl disable --now nvme-power-tune.service cpu-power-tune.service 2>/dev/null || true
sudo rm -f /usr/local/sbin/nvme-power-tune /etc/udev/rules.d/99-nvme-power-tune.rules \
    /etc/systemd/system/nvme-power-tune.service /usr/lib/systemd/system-sleep/nvme-power-tune \
    /usr/local/sbin/cpu-power-tune /etc/default/cpu-power-tune /etc/udev/rules.d/99-cpu-power-tune.rules \
    /etc/systemd/system/cpu-power-tune.service /usr/lib/systemd/system-sleep/cpu-power-tune \
    /etc/systemd/system/thermald.service.d/override.conf /etc/sudoers.d/cpu-power-tune
sudo rmdir /etc/systemd/system/thermald.service.d 2>/dev/null || true
grep -q cpu-power-tune "$H/.config/gamemode.ini" 2>/dev/null && rm -f "$H/.config/gamemode.ini"
sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl restart thermald   # back to --adaptive, which restores the BIOS power limits
LV=${LV:-ubuntu-vg/ubuntu-lv}
sudo lvchange --readahead auto "$LV"
echo "Removed. NVMe APST returns to the kernel default at next reboot."
