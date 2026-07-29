#!/bin/sh
# OMR Connect installer / updater - patches the BASE LuCI system
# Prefer VPS mirror when GitHub is unreachable from the router.
RAW_VPS="${OMR_OTA_VPS:-http://191.218.161.141:8088}"
RAW_GH="https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main"
RAW_CDN="https://cdn.jsdelivr.net/gh/mmlktahmd4-cmd/omr-dashboard@main"

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -4 -fsSL -m 25 "$1"
  else uclient-fetch -q -T 25 -O - "$1"; fi
}
fetch_any() {
  rel="$1"
  for b in "$RAW_VPS" "$RAW_GH" "$RAW_CDN"; do
    if fetch "$b/$rel"; then return 0; fi
  done
  return 1
}
dl() {
  t="$2.new.$$"
  mkdir -p "$(dirname "$2")"
  if fetch_any "$1" > "$t" && [ -s "$t" ]; then
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

dl "cgi-bin/omr-api" /www/cgi-bin/omr-api || FAIL=1
fix /www/cgi-bin/omr-api
chmod +x /www/cgi-bin/omr-api 2>/dev/null || true

dl "luci-theme/header.htm" /usr/lib/lua/luci/view/themes/openmptcprouter/header.htm || FAIL=1
dl "luci-theme/footer.htm" /usr/lib/lua/luci/view/themes/openmptcprouter/footer.htm || FAIL=1
dl "luci-theme/omr-connect.css" /www/luci-static/openmptcprouter/omr-connect.css || FAIL=1
fix /usr/lib/lua/luci/view/themes/openmptcprouter/header.htm
fix /usr/lib/lua/luci/view/themes/openmptcprouter/footer.htm

if [ -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm ] && [ ! -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm.orig ]; then
  cp -f /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm.orig
fi
dl "luci-view/wanstatus.htm" /usr/lib/lua/luci/view/openmptcprouter/wanstatus.htm || FAIL=1
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

mkdir -p /www /www/omr-dash
cat > /www/index.html <<'HTML'
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; URL=cgi-bin/luci/admin/system/connect/status" />
</head>
<body><p><a href="cgi-bin/luci/admin/system/connect/status">Connect</a></p></body>
</html>
HTML

dl "VERSION" /www/omr-dash/VERSION || FAIL=1
rm -rf /tmp/luci-* /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null || true
/etc/init.d/uhttpd reload 2>/dev/null || true

echo "OMR Connect installed/updated to $(cat /www/omr-dash/VERSION 2>/dev/null)"
[ "$FAIL" = "0" ] || echo "WARNING: some files failed to download"
exit "$FAIL"