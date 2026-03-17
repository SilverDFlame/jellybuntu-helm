#!/bin/bash
# Ensures Prowlarr's config.xml has PostgreSQL connection settings.
# Runs on every container start via /custom-cont-init.d/.
# On first boot with existing SQLite data, Prowlarr auto-migrates to Postgres.

CONFIG="/config/config.xml"

inject_postgres() {
  local pg_user="prowlarr"
  local pg_host="192.168.30.16"
  local pg_port="5432"
  local pg_main="prowlarr_main"
  local pg_log="prowlarr_log"
  local pg_pass="${MEDIA_POSTGRES_PASSWORD:-}"

  if [ -z "$pg_pass" ]; then
    echo "[prowlarr-init] WARNING: MEDIA_POSTGRES_PASSWORD not set, skipping Postgres config"
    return 1
  fi

  if grep -q '<PostgresHost>' "$CONFIG"; then
    echo "[prowlarr-init] Postgres config already present"
    return 0
  fi

  sed -i "s|</Config>|  <PostgresUser>${pg_user}</PostgresUser>\n  <PostgresPassword>${pg_pass}</PostgresPassword>\n  <PostgresHost>${pg_host}</PostgresHost>\n  <PostgresPort>${pg_port}</PostgresPort>\n  <PostgresMainDb>${pg_main}</PostgresMainDb>\n  <PostgresLogDb>${pg_log}</PostgresLogDb>\n</Config>|" "$CONFIG"
  echo "[prowlarr-init] Postgres config injected"
}

set_api_key() {
  local api_key="${PROWLARR_API_KEY:-}"
  [ -z "$api_key" ] && return 0

  if grep -q '<ApiKey>' "$CONFIG"; then
    sed -i "s|<ApiKey>.*</ApiKey>|<ApiKey>${api_key}</ApiKey>|" "$CONFIG"
  else
    sed -i "s|</Config>|  <ApiKey>${api_key}</ApiKey>\n</Config>|" "$CONFIG"
  fi
}

if [ -f "$CONFIG" ]; then
  inject_postgres
  set_api_key
  echo "[prowlarr-init] Config patched successfully"
else
  echo "[prowlarr-init] No config.xml yet — Prowlarr will generate one on first start"
  # Create minimal config with Postgres settings for first boot
  cat > "$CONFIG" <<XMLEOF
<Config>
  <PostgresUser>prowlarr</PostgresUser>
  <PostgresPassword>${MEDIA_POSTGRES_PASSWORD}</PostgresPassword>
  <PostgresHost>192.168.30.16</PostgresHost>
  <PostgresPort>5432</PostgresPort>
  <PostgresMainDb>prowlarr_main</PostgresMainDb>
  <PostgresLogDb>prowlarr_log</PostgresLogDb>
  <ApiKey>${PROWLARR_API_KEY}</ApiKey>
</Config>
XMLEOF
  echo "[prowlarr-init] Created config.xml with Postgres settings"
fi
