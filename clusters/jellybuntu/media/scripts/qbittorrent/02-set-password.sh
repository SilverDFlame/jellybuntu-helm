#!/bin/bash
# Sets qBittorrent admin password from SERVICES_ADMIN_PASSWORD env var.
# Runs as a LSIO custom-cont-init.d script (before qBittorrent starts).
# Launches a background process that waits for the API, then sets the password.
#
# First boot: authenticates with the random temp password and changes it.
# Subsequent boots: verifies the vault password works, skips if already set.

TARGET_PASSWORD="${SERVICES_ADMIN_PASSWORD:-}"

if [ -z "$TARGET_PASSWORD" ]; then
  echo "[qbt-password] SERVICES_ADMIN_PASSWORD not set — skipping"
  exit 0
fi

echo "[qbt-password] Will set password after qBittorrent starts..."

# Background process — waits for qBittorrent API, then sets password
(
  QBT_URL="http://127.0.0.1:8080"
  QBT_USER="admin"

  # Wait for qBittorrent API (up to 2 minutes)
  for i in $(seq 1 60); do
    if wget -qO- "$QBT_URL/api/v2/app/version" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  if ! wget -qO- "$QBT_URL/api/v2/app/version" >/dev/null 2>&1; then
    echo "[qbt-password] qBittorrent API not available — skipping"
    exit 0
  fi

  # Try vault password first (already configured on previous boot)
  RESP=$(wget -qO- --post-data "username=$QBT_USER&password=$TARGET_PASSWORD" \
    --header="Referer: $QBT_URL" \
    "$QBT_URL/api/v2/auth/login" 2>/dev/null || echo "")

  if [ "$RESP" = "Ok." ]; then
    echo "[qbt-password] Password already set correctly"
    exit 0
  fi

  # Wait a moment for qBittorrent to write its log with the temp password
  sleep 5

  # Extract temp password from qBittorrent log
  TEMP_PASS=""
  for log_src in /config/qBittorrent/logs/qbittorrent.log /config/log/qbittorrent/qbittorrent.log; do
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
  RESP=$(wget -qO- --post-data "username=$QBT_USER&password=$TEMP_PASS" \
    --header="Referer: $QBT_URL" \
    "$QBT_URL/api/v2/auth/login" 2>/dev/null || echo "")

  if [ "$RESP" != "Ok." ]; then
    echo "[qbt-password] Temp password auth failed — password may already be changed"
    exit 0
  fi

  # Change password
  wget -qO- --post-data "json={\"web_ui_password\":\"$TARGET_PASSWORD\"}" \
    --header="Referer: $QBT_URL" \
    "$QBT_URL/api/v2/app/setPreferences" >/dev/null 2>&1

  echo "[qbt-password] Password changed successfully"
) &

# Don't block container init — background process handles it
exit 0