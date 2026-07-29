# OMR Connect

Custom **base LuCI edition** for OpenMPTCProuter — not a parallel page.

This package **replaces** the stock OpenMPTCProuter Status page, theme header/footer,
and branding inside the router firmware UI. Updates ship over GitHub.

## What changes inside the system

- LuCI theme branding → **Connect**
- Status page (`wanstatus`) → modern connect dashboard (WANs / VPS / VPN / Proxy + one-click reconnect)
- Default menu landing → Status (instead of Wizard)
- Root URL `http://ROUTER/` → opens the LuCI Connect Status page
- GitHub OTA updates from this repo

## Install / Update (on the router)

```sh
wget -qO- https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main/install.sh | sh
```

Or from the Status page: **التحديثات عبر GitHub → تحقق → تحديث الآن**.

## Contents

| Path | Role |
|------|------|
| `luci-theme/` | LuCI header/footer + `omr-connect.css` overlay |
| `luci-view/wanstatus.htm` | Replaces original OMR Status page |
| `cgi-bin/omr-api` | Fast status/actions/OTA backend |
| `install.sh` | Applies all of the above into the live system |
| `VERSION` | Bump this when publishing updates |

## Version

Current: see `VERSION`.
