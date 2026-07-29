#!/bin/sh
# OMR Connect installer / updater — patches the BASE LuCI system (not a parallel page).
# wget -qO- https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main/install.sh | sh
set -e
RAW="https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main"

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL -m 30 "$1"
  else uclient-fetch -q -T 30 -O - "$1"; fi
}
dl() {
  t="$2.new.$$"
  mkdir -p "$(dirname "$2")"
  if fetch "$1" > "$t" && [ -s "$t" ]; then
    mv "$t" "$2"
  else
    rm -f "$t"; echo "FAILED: $1"; return 1
  fi
}
fix() { sed -i 's/\r$//' "$1" 2>/dev/null || true; }

echo "== OMR Connect: installing into LuCI base system =="

# Fast API used by the new Status page
dl "$RAW/cgi-bin/omr-api" /www/cgi-bin/omr-api
fix /www/cgi-bin/omr-api
chmod +x /www/cgi-bin/omr-api

# Theme overlay (brand + look)
dl "$RAW/luci-theme/header.htm" /usr/lib/lua/luci/view/themes/openmptcprouter/header.htm
dl "$RAW/luci-theme/footer.htm" /usr/lib/lua/luci/view/themes/openmptcprouter/footer.htm
dl "$RAW/luci-theme/omr-connect.css" /www/luci-static/openmptcprouter/omr-connect.css
fix /usr/lib/lua/luci/view/themes/openmptcprouter/header.htm
fix /usr/lib/lua/luci/view/themes/openmptcprouter/footer.htm

# Replace the original Status page (wanstatus) inside LuCI
if [ -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm ] && [ ! -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm.orig ]; then
  cp -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm.orig
fi
dl "$RAW/luci-view/wanstatus.htm" /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm
fix /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm

# Brand + open Status first (instead of Wizard)
uci -q set openmptcprouter.settings.menu='Connect'
uci -q commit openmptcprouter

CTRL=/usr/lib/lua/luci/controller/openmptcprouter.lua
if [ -f "$CTRL" ]; then
  if [ ! -f "$CTRL.orig" ]; then cp -f "$CTRL" "$CTRL.orig"; fi
  # Prefer Status as the default landing under the Connect menu
  sed -i 's/alias("admin", "system", menuentry:lower(), "wizard")/alias("admin", "system", menuentry:lower(), "status")/g' "$CTRL"
  # Put Status order before Wizard when possible
  sed -i 's/template("openmptcprouter\/wanstatus"), _("Status"), 2)/template("openmptcprouter\/wanstatus"), _("Status"), 1)/g' "$CTRL"
  sed -i 's/template("openmptcprouter\/wizard"), _("Settings Wizard"), 1)/template("openmptcprouter\/wizard"), _("Settings Wizard"), 2)/g' "$CTRL"
fi

# Root page opens the BASE LuCI Connect status (not a parallel page)
cat > /www/index.html <<'HTML'
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
	<meta charset="utf-8">
	<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
	<meta http-equiv="Pragma" content="no-cache" />
	<meta http-equiv="Expires" content="0" />
	<meta http-equiv="refresh" content="0; URL=cgi-bin/luci/admin/system/connect/status" />
	<style>
		body{background:#0b1220;color:#e8edf7;font-family:system-ui,Tahoma,Arial,sans-serif;
			display:grid;place-items:center;height:100vh;margin:0}
		a{color:#7dd3fc}
	</style>
</head>
<body>
	<p>جاري فتح لوحة Connect…</p>
	<p><a href="cgi-bin/luci/admin/system/connect/status">افتح اللوحة</a></p>
</body>
</html>
HTML

# Version stamp + clear LuCI cache
dl "$RAW/VERSION" /www/omr-dash/VERSION
rm -rf /tmp/luci-* /tmp/luci-indexcache* 2>/dev/null || true
/etc/init.d/uhttpd reload 2>/dev/null || true

echo "OMR Connect installed/updated to $(cat /www/omr-dash/VERSION 2>/dev/null)"
echo "Open: http://192.168.100.1/  →  LuCI Status (Connect)"
