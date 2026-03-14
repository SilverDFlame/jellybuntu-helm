#!/bin/bash
# Sets qBittorrent admin password from SERVICES_ADMIN_PASSWORD env var.
# Runs as a LSIO custom-services.d one-shot script (after qBittorrent starts).
#
# First boot: authenticates with the random temp password and changes it.
# Subsequent boots: verifies the vault password works, skips if already set.

set -euo pipefail

QBT_URL="http://127.0.0.1:8080"
QBT_USER="admin"
TARGET_PASSWORD="${SERVICES_ADMIN_PASSWORD:-}"

if [ -z "$TARGET_PASSWORD" ]; then
  echo "[qbt-password] SERVICES_ADMIN_PASSWORD not set — skipping"
  exit 0
fi

# Wait for qBittorrent API
echo "[qbt-password] Waiting for qBittorrent API..."
for i in $(seq 1 60); do
  if curl -sf "$QBT_URL/api/v2/app/version" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Try vault password first (already configured on previous boot)
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE"' EXIT

RESP=$(curl -s -c "$COOKIE" -X POST \
  -H "Referer: $QBT_URL" \
  -d "username=$QBT_USER&password=$TARGET_PASSWORD" \
  "$QBT_URL/api/v2/auth/login" 2>/dev/null || echo "")

if [ "$RESP" = "Ok." ]; then
  echo "[qbt-password] Password already set correctly"
  exit 0
fi

# Extract temp password from qBittorrent log output
TEMP_PASS=""
for log_src in /config/log/qbittorrent/qbittorrent.log /var/log/qbittorrent.log; do
  if [ -f "$log_src" ]; then
    TEMP_PASS=$(grep -o 'temporary password.*: [^ ]*' "$log_src" 2>/dev/null | tail -1 | awk '{print $NF}' || echo "")
    [ -n "$TEMP_PASS" ] && break
  fi
done

if [ -z "$TEMP_PASS" ]; then
  echo "[qbt-password] Could not find temp password — set manually via UI"
  exit 0
fi

# Authenticate with temp password
RESP=$(curl -s -c "$COOKIE" -X POST \
  -H "Referer: $QBT_URL" \
  -d "username=$QBT_USER&password=$TEMP_PASS" \
  "$QBT_URL/api/v2/auth/login" 2>/dev/null || echo "")

if [ "$RESP" != "Ok." ]; then
  echo "[qbt-password] Temp password auth failed — password may already be changed"
  exit 0
fi

# Change password
curl -s -b "$COOKIE" -X POST \
  -H "Referer: $QBT_URL" \
  -d "json={\"web_ui_password\":\"$TARGET_PASSWORD\"}" \
  "$QBT_URL/api/v2/app/setPreferences" >/dev/null 2>&1

echo "[qbt-password] Password changed successfully"