#!/bin/sh
# OMR Connect installer / updater â€” patches the BASE LuCI system (not a parallel page).
# wget -qO- https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main/install.sh | sh
RAW="https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main"
CB=$(date +%s)

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL -m 45 "$1"
  else uclient-fetch -q -T 45 -O - "$1"; fi
}
dl() {
  t="$2.new.$$"
  mkdir -p "$(dirname "$2")"
  url="$1"
  case "$url" in
    *\?*) : ;;
    *) url="$1?t=$CB" ;;
  esac
  if fetch "$url" > "$t" && [ -s "$t" ]; then
    mv "$t" "$2"
    return 0
  fi
  # retry without cache buster
  if fetch "$1" > "$t" && [ -s "$t" ]; then
    mv "$t" "$2"
    return 0
  fi
  rm -f "$t"
  echo "FAILED: $1"
  return 1
}
fix() { sed -i 's/\r$//' "$1" 2>/dev/null || true; }

echo "== OMR Connect: installing into LuCI base system =="
FAIL=0

dl "$RAW/cgi-bin/omr-api" /www/cgi-bin/omr-api || FAIL=1
fix /www/cgi-bin/omr-api
chmod +x /www/cgi-bin/omr-api 2>/dev/null || true

dl "$RAW/luci-theme/header.htm" /usr/lib/lua/luci/view/themes/openmptcprouter/header.htm || FAIL=1
dl "$RAW/luci-theme/footer.htm" /usr/lib/lua/luci/view/themes/openmptcprouter/footer.htm || FAIL=1
dl "$RAW/luci-theme/omr-connect.css" /www/luci-static/openmptcprouter/omr-connect.css || FAIL=1
fix /usr/lib/lua/luci/view/themes/openmptcprouter/header.htm
fix /usr/lib/lua/luci/view/themes/openmptcprouter/footer.htm

if [ -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm ] && [ ! -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm.orig ]; then
  cp -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm.orig
fi
dl "$RAW/luci-view/wanstatus.htm" /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm || FAIL=1
fix /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm

uci -q set openmptcprouter.settings.menu='Connect'
uci -q commit openmptcprouter

CTRL=/usr/lib/lua/luci/controller/openmptcprouter.lua
if [ -f "$CTRL" ]; then
  if [ ! -f "$CTRL.orig" ]; then cp -f "$CTRL" "$CTRL.orig"; fi
  sed -i 's/alias("admin", "system", menuentry:lower(), "wizard")/alias("admin", "system", menuentry:lower(), "status")/g' "$CTRL"
  sed -i 's/template("openmptcprouter\/wanstatus"), _("Status"), 2)/template("openmptcprouter\/wanstatus"), _("Status"), 1)/g' "$CTRL"
  sed -i 's/template("openmptcprouter\/wizard"), _("Settings Wizard"), 1)/template("openmptcprouter\/wizard"), _("Settings Wizard"), 2)/g' "$CTRL"
fi

mkdir -p /www
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
		body{background:#e8edf3;color:#1a2433;font-family:Tahoma,Arial,sans-serif;
			display:grid;place-items:center;height:100vh;margin:0}
		a{color:#2a66e0}
	</style>
</head>
<body>
	<p>ط¬ط§ط±ظٹ ظپطھط­ ظ„ظˆط­ط© Connectâ€¦</p>
	<p><a href="cgi-bin/luci/admin/system/connect/status">ط§ظپطھط­ ط§ظ„ظ„ظˆط­ط©</a></p>
</body>
</html>
HTML

mkdir -p /www/omr-dash
dl "$RAW/VERSION" /www/omr-dash/VERSION || FAIL=1
rm -rf /tmp/luci-* /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null || true
/etc/init.d/uhttpd reload 2>/dev/null || true

echo "OMR Connect installed/updated to $(cat /www/omr-dash/VERSION 2>/dev/null)"
[ "$FAIL" = "0" ] || echo "WARNING: some files failed to download"
exit "$FAIL"
