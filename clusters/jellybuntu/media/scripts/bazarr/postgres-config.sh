#!/bin/bash
# Patches Bazarr's config.yaml to enable PostgreSQL.
# Runs on every container start via /custom-cont-init.d/.
# On first boot with existing SQLite data, Bazarr auto-migrates to Postgres.

CONFIG="/config/config/config.yaml"

patch_postgres() {
  local pg_pass="${MEDIA_POSTGRES_PASSWORD:-}"

  if [ -z "$pg_pass" ]; then
    echo "[bazarr-init] WARNING: MEDIA_POSTGRES_PASSWORD not set, skipping Postgres config"
    return 1
  fi

  # Only patch the postgresql section (between 'postgresql:' and the next top-level key)
  sed -i '/^postgresql:/,/^[a-z]/{
    s/^  database: .*/  database: bazarr_main/
    s/^  enabled: .*/  enabled: true/
    s/^  host: .*/  host: 192.168.30.16/
    s/^  username: .*/  username: bazarr/
  }' "$CONFIG"

  # Password handled separately to avoid sed delimiter issues
  sed -i "/^postgresql:/,/^[a-z]/{
    s|^  password: .*|  password: '${pg_pass}'|
  }" "$CONFIG"

  echo "[bazarr-init] PostgreSQL config patched"
}

if [ -f "$CONFIG" ]; then
  if grep -q "enabled: true" "$CONFIG" 2>/dev/null && grep -q "host: 192.168.30.16" "$CONFIG" 2>/dev/null; then
    echo "[bazarr-init] PostgreSQL already configured"
  else
    patch_postgres
  fi
else
  echo "[bazarr-init] No config.yaml yet — Bazarr will create it on first run, Postgres config on next restart"
fi
