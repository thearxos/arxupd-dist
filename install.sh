#!/usr/bin/env bash
set -e
D=$(cd "$(dirname "$0")" && pwd)
sudo install -m755 "$D/arxupd" /usr/local/bin/arxupd
sudo install -Dm644 "$D/repos.list" /etc/arxos/repos.list   # legacy manifest; arx tools now reads the R2 tools.json
# The background git-pull auto-updater is RETIRED. It fought the R2 delivery model — on its boot
# +6h timer it re-pulled the stale `-dist` mirrors and reinstalled OLD binaries over the latest
# R2-delivered ones (observed reverting arxos-dev after a reboot). Updates are now user-initiated
# via `arx update` / the Control Center, and `arxupd` just delegates to `arx tools` (R2). Actively
# tear down any previously-installed timer/service so an existing box stops reverting itself.
sudo systemctl disable --now arxupd.timer 2>/dev/null || true
sudo systemctl disable --now arxupd.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/arxupd.timer /etc/systemd/system/arxupd.service
sudo systemctl daemon-reload 2>/dev/null || true
echo "arxupd installed (delegates to 'arx tools' → R2; background auto-update timer retired)"
