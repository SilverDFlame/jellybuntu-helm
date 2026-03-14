#!/bin/bash
# Sets qBittorrent admin password from SERVICES_ADMIN_PASSWORD env var.
# Runs as a LSIO custom-cont-init.d script (before qBittorrent starts).
# Launches a background process that waits for the API, then sets the password.
#
# Always sets the password on every boot — can't reliably detect if it's
# already correct because LocalHostAuth=false bypasses auth for localhost.

TARGET_PASSWORD="${SERVICES_ADMIN_PASSWORD:-}"

if [ -z "$TARGET_PASSWORD" ]; then
  echo "[qbt-password] SERVICES_ADMIN_PASSWORD not set — skipping"
  exit 0
fi

echo "[qbt-password] Will set password after qBittorrent starts..."

# Background process — waits for qBittorrent API, then sets password
(
  QBT_URL="http://127.0.0.1:8080"

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

  # Set password unconditionally (localhost auth bypass means we can
  # always call setPreferences without logging in first)
  wget -qO- --post-data "json={\"web_ui_password\":\"$TARGET_PASSWORD\"}" \
    --header="Referer: $QBT_URL" \
    "$QBT_URL/api/v2/app/setPreferences" >/dev/null 2>&1

  echo "[qbt-password] Password set from vault secret"
) &

# Don't block container init — background process handles it
exit 0