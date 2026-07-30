#!/bin/sh
# OMR Connect installer / updater - patches the BASE LuCI system
# Always installs from the NEWEST mirror (by VERSION), never from a stale one.
RAW_VPS="${OMR_OTA_VPS:-http://191.218.161.141:8088}"
RAW_GH="https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main"
RAW_CDN="https://cdn.jsdelivr.net/gh/mmlktahmd4-cmd/omr-dashboard@main"
# إن مرّر omr-api مصدراً محدداً (الأحدث) نستخدمه حصراً
RAW_FORCE="${OMR_OTA_BASE:-}"

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -4 -fsSL -m 25 "$1"
  else uclient-fetch -q -T 25 -O - "$1"; fi
}
ver_parts() {
  printf '%s' "$1" | tr -cd '0-9.' | awk -F. '{printf "%d %d %d", $1+0, $2+0, $3+0}'
}
ver_gt() {
  set -- $(ver_parts "$1") $(ver_parts "$2")
  [ "$1" -gt "$4" ] 2>/dev/null && return 0
  [ "$1" -lt "$4" ] 2>/dev/null && return 1
  [ "$2" -gt "$5" ] 2>/dev/null && return 0
  [ "$2" -lt "$5" ] 2>/dev/null && return 1
  [ "$3" -gt "$6" ] 2>/dev/null && return 0
  return 1
}
pick_base() {
  if [ -n "$RAW_FORCE" ]; then
    BEST_BASE="$RAW_FORCE"
    BEST_VER=$(fetch "$BEST_BASE/VERSION" 2>/dev/null | tr -d ' \r\n')
    [ -z "$BEST_VER" ] && BEST_VER="${OMR_EXPECT_VER:-unknown}"
    echo "Using forced OTA base: $BEST_BASE (VERSION=$BEST_VER)"
    return 0
  fi
  BEST_BASE=""; BEST_VER="0"
  for b in "$RAW_GH" "$RAW_CDN" "$RAW_VPS"; do
    v=$(fetch "$b/VERSION" 2>/dev/null | tr -d ' \r\n')
    [ -z "$v" ] && continue
    echo "probe $b -> $v"
    if [ -z "$BEST_BASE" ] || ver_gt "$v" "$BEST_VER"; then
      BEST_BASE="$b"; BEST_VER="$v"
    fi
  done
  [ -n "$BEST_BASE" ] || return 1
  echo "Selected newest OTA base: $BEST_BASE (VERSION=$BEST_VER)"
}
fetch_any() {
  rel="$1"
  [ -n "$BEST_BASE" ] || return 1
  fetch "$BEST_BASE/$rel"
}
dl() {
  t="$2.new.$$"
  mkdir -p "$(dirname "$2")"
  if fetch_any "$1" > "$t" && [ -s "$t" ]; then
    mv "$t" "$2"
    return 0
  fi
  rm -f "$t"
  echo "FAILED: $1 (from $BEST_BASE)"
  return 1
}
fix() { sed -i 's/\r$//' "$1" 2>/dev/null || true; }

echo "== OMR Connect: installing into LuCI base system =="
OLD_VER=$(cat /www/omr-dash/VERSION 2>/dev/null | tr -d ' \r\n')
[ -z "$OLD_VER" ] && OLD_VER=0

if ! pick_base; then
  echo "ERROR: no OTA source reachable"
  exit 1
fi

# ارفض التخفيض إن كان المصدر أقدم من الجهاز
if [ "$BEST_VER" != "unknown" ] && [ -n "$OLD_VER" ]; then
  if ver_gt "$OLD_VER" "$BEST_VER"; then
    echo "ERROR: refusing downgrade $OLD_VER -> $BEST_VER (stale mirror)"
    exit 2
  fi
fi

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

dl "hotplug/98-omr-connect-discover" /etc/hotplug.d/net/98-omr-connect-discover || true
if [ -f /etc/hotplug.d/net/98-omr-connect-discover ]; then
  fix /etc/hotplug.d/net/98-omr-connect-discover
  chmod +x /etc/hotplug.d/net/98-omr-connect-discover 2>/dev/null || true
fi

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
NEW_VER=$(cat /www/omr-dash/VERSION 2>/dev/null | tr -d ' \r\n')
# حماية أخيرة: لا تُبقِ VERSION أقدم من السابق
if [ -n "$NEW_VER" ] && [ -n "$OLD_VER" ] && ver_gt "$OLD_VER" "$NEW_VER"; then
  echo "$OLD_VER" > /www/omr-dash/VERSION
  echo "ERROR: restored VERSION (refused downgrade to $NEW_VER)"
  FAIL=1
fi

rm -rf /tmp/luci-* /tmp/luci-indexcache* /tmp/luci-modulecache 2>/dev/null || true
/etc/init.d/uhttpd reload 2>/dev/null || true

echo "OMR Connect installed/updated to $(cat /www/omr-dash/VERSION 2>/dev/null) from $BEST_BASE"
[ "$FAIL" = "0" ] || echo "WARNING: some files failed to download"
exit "$FAIL"
