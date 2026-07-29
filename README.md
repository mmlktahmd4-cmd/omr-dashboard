# OMR Dashboard

A modern, lightweight control panel for OpenMPTCProuter (OMR) that runs **inside the router**.
It focuses on easy connectivity: live status of every WAN, the VPS, the VPN tunnel and the
proxy, plus one-click connect / reconnect actions and plain-language problem hints.

Open it at: `http://192.168.100.1/` (auto-opens) or `http://192.168.100.1/omr-dash/`

## Install / Update (on the router over SSH)

```sh
wget -qO- https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main/install.sh | sh
```

You can also update from inside the dashboard: **التحديثات عبر GitHub → تحقق من التحديثات → تحديث الآن**.

## Contents

- `omr-dash/index.html` — the dashboard UI (Arabic, RTL).
- `cgi-bin/omr-api` — shell CGI backend (status + actions + OTA update).
- `www-index.html` — landing page that auto-redirects to the dashboard.
- `install.sh` — installer / updater (used by the "Update now" button too).
- `VERSION` — current version; the dashboard compares it against this file to detect updates.

## How updates work

The dashboard reads its local version from `/www/omr-dash/VERSION` and compares it to the
`VERSION` file in this repo. Pressing **تحديث الآن** downloads `install.sh` from `main` and runs
it, which refreshes every file (including the API itself). Bump `VERSION` when you publish changes.
