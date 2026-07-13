#!/usr/bin/env bash
set -e
D=$(cd "$(dirname "$0")" && pwd)
sudo install -m755 "$D/arxupd" /usr/local/bin/arxupd
sudo install -Dm644 "$D/repos.list" /etc/arxos/repos.list
# Auto-update via a systemd timer — the thearxos repos act as the update server.
sudo install -Dm644 "$D/arxupd.service" /etc/systemd/system/arxupd.service
sudo install -Dm644 "$D/arxupd.timer"   /etc/systemd/system/arxupd.timer
sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl enable arxupd.timer 2>/dev/null || true
echo "arxupd installed + auto-update timer enabled (boot + every 6h)"
