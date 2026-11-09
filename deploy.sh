#!/bin/bash
# Run by cPanel Git Version Control ("Deploy HEAD Commit", via .cpanel.yml) from the depobat-deploy clone.
#  1. installs the prebuilt app into ~/depobat-app (server/ is replaced as a whole);
#  2. once: moves the old static site out of public_html into ~/site-vechi-<date>
#     and reduces .htaccess to the Node.js (Passenger) block + HTTPS redirect;
#  3. restarts the Node.js app (tmp/restart.txt).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/depobat-app"
PH="$HOME/public_html"
STAMP="$(date +%Y%m%d-%H%M%S)"
log() { echo "[depobat-deploy $STAMP] $*"; }

# ── 1. App files ────────────────────────────────────────────────
mkdir -p "$APP/tmp"
rm -rf "$APP/server.new" "$APP/server.old"
cp -R "$SRC/server" "$APP/server.new"
if [ -d "$APP/server" ]; then mv "$APP/server" "$APP/server.old"; fi
mv "$APP/server.new" "$APP/server"
rm -rf "$APP/server.old"
cp "$SRC/app.js" "$SRC/package.json" "$SRC/CITESTE-MA.txt" "$APP/"
log "app installed in $APP ($(cat "$SRC/VERSION" 2>/dev/null || echo unknown))"

# ── 2. Old static site in public_html (only while it is still there) ──
if [ -f "$PH/index.html" ] || [ -d "$PH/_next" ] || [ -f "$PH/api/submit.php" ]; then
  BK="$HOME/site-vechi-$STAMP"
  mkdir -p "$BK"
  shopt -s dotglob nullglob
  for f in "$PH"/*; do
    case "$(basename "$f")" in
      .htaccess | .well-known | cgi-bin) ;;
      *) mv "$f" "$BK/" ;;
    esac
  done
  shopt -u dotglob nullglob
  if [ -f "$PH/.htaccess" ]; then
    cp "$PH/.htaccess" "$BK/.htaccess"
    # Keep only the block written by "Setup Node.js App"; drop the static-site rules.
    awk '/CLOUDLINUX PASSENGER CONFIGURATION BEGIN/{keep=1} keep{print} /CLOUDLINUX PASSENGER CONFIGURATION END/{keep=0}' \
      "$BK/.htaccess" > "$PH/.htaccess.new"
  else
    : > "$PH/.htaccess.new"
  fi
  cat >> "$PH/.htaccess.new" <<'EOF'

# Depobat — HTTPS + domeniu fără www (restul îl servește aplicația Node.js)
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTPS} off [OR]
  RewriteCond %{HTTP_HOST} ^www\. [NC]
  RewriteRule ^ https://depobat.ro%{REQUEST_URI} [L,R=301]
</IfModule>
EOF
  mv "$PH/.htaccess.new" "$PH/.htaccess"
  log "old static site moved to $BK"
fi

# ── 3. Restart ──────────────────────────────────────────────────
touch "$APP/tmp/restart.txt"
log "restart requested"
