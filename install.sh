#!/bin/sh
# OMR dashboard installer / updater.
# Pulls the latest dashboard UI + API from GitHub and installs it on the router.
#
# One-line install/update on the router:
#   wget -qO- https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main/install.sh | sh
#
set -e
RAW="https://raw.githubusercontent.com/mmlktahmd4-cmd/omr-dashboard/main"

fetch() { # url -> stdout
  if command -v curl >/dev/null 2>&1; then curl -fsSL -m 30 "$1"
  else uclient-fetch -q -T 30 -O - "$1"; fi
}

dl() { # url dest  (download to temp, install only on success + non-empty)
  t="$2.new.$$"
  if fetch "$1" > "$t" && [ -s "$t" ]; then
    mv "$t" "$2"
  else
    rm -f "$t"; echo "FAILED: $1"; return 1
  fi
}

mkdir -p /www/omr-dash /www/cgi-bin
dl "$RAW/omr-dash/index.html" /www/omr-dash/index.html
dl "$RAW/cgi-bin/omr-api"     /www/cgi-bin/omr-api
dl "$RAW/www-index.html"      /www/index.html
dl "$RAW/VERSION"             /www/omr-dash/VERSION

sed -i 's/\r$//' /www/cgi-bin/omr-api
chmod +x /www/cgi-bin/omr-api

echo "OMR dashboard installed/updated to $(cat /www/omr-dash/VERSION 2>/dev/null)"
