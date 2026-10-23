#!/bin/sh
# Install NVMe + CPU power tuning.
#   nvme-power-tune: AC -> APST off + performance profile; battery -> kernel APST + balanced
#   cpu-power-tune:  AC -> 45/65 W, gaming (GameMode) or battery -> stock 20/25 W
# Also sets 1 MiB readahead on the root LV and runs thermald without --adaptive.
set -e
cd "$(dirname "$0")/files"
U=${SUDO_USER:-$(id -un)}

# NVMe
sudo install -m 755 nvme-power-tune /usr/local/sbin/nvme-power-tune
sudo install -m 644 99-nvme-power-tune.rules /etc/udev/rules.d/99-nvme-power-tune.rules
sudo install -m 644 nvme-power-tune.service /etc/systemd/system/nvme-power-tune.service
sudo install -m 755 nvme-power-tune.sleep /usr/lib/systemd/system-sleep/nvme-power-tune

# CPU
sudo install -m 755 cpu-power-tune /usr/local/sbin/cpu-power-tune
[ -e /etc/default/cpu-power-tune ] || sudo install -m 644 cpu-power-tune.default /etc/default/cpu-power-tune
sudo install -m 644 99-cpu-power-tune.rules /etc/udev/rules.d/99-cpu-power-tune.rules
sudo install -m 644 cpu-power-tune.service /etc/systemd/system/cpu-power-tune.service
sudo install -m 755 cpu-power-tune.sleep /usr/lib/systemd/system-sleep/cpu-power-tune
sudo install -d /etc/systemd/system/thermald.service.d
sudo install -m 644 thermald-override.conf /etc/systemd/system/thermald.service.d/override.conf

# GameMode hooks: allow only these two exact commands without a password.
T=$(mktemp)
printf '%s ALL=(root) NOPASSWD: /usr/local/sbin/cpu-power-tune game-start, /usr/local/sbin/cpu-power-tune game-end\n' "$U" > "$T"
sudo visudo -cqf "$T" && sudo install -m 440 "$T" /etc/sudoers.d/cpu-power-tune
rm -f "$T"
H=$(getent passwd "$U" | cut -d: -f6)
if [ -e "$H/.config/gamemode.ini" ]; then
    echo "Note: $H/.config/gamemode.ini exists; add the [custom] start/end lines from files/gamemode.ini yourself."
else
    install -D -m 644 gamemode.ini "$H/.config/gamemode.ini"
fi

sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl restart thermald
sudo systemctl enable --now nvme-power-tune.service cpu-power-tune.service
sudo systemctl restart cpu-power-tune.service

LV=${LV:-ubuntu-vg/ubuntu-lv}
sudo lvchange --readahead 2048 "$LV" || true   # 2048 sectors = 1 MiB
journalctl -t nvme-power-tune -t cpu-power-tune -n 2 --no-pager -o cat
