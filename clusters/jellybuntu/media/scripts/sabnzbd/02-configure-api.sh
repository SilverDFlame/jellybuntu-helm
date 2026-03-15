#!/bin/sh
# Configures SABnzbd via API after startup: servers, categories, auth, watch folder.
# Runs as background subshell from custom-cont-init.d (before SABnzbd starts).

API_KEY="${SABNZBD_API_KEY:-}"

if [ -z "$API_KEY" ]; then
  echo "[sabnzbd-api] SABNZBD_API_KEY not set — skipping"
  exit 0
fi

echo "[sabnzbd-api] Will configure after SABnzbd starts..."

(
  API_URL="http://127.0.0.1:8080"

  api_call() {
    wget -qO- "${API_URL}/api?apikey=${API_KEY}&output=json&$1" 2>/dev/null
  }

  # Wait for SABnzbd API
  for i in $(seq 1 60); do
    if api_call "mode=version" | grep -q "version"; then
      break
    fi
    sleep 2
  done

  if ! api_call "mode=version" | grep -q "version"; then
    echo "[sabnzbd-api] API not available — skipping"
    exit 0
  fi

  echo "[sabnzbd-api] Connected to SABnzbd"

  # --- Download directories ---
  api_call "mode=set_config&section=misc&keyword=complete_dir&value=/data/usenet" >/dev/null
  api_call "mode=set_config&section=misc&keyword=download_dir&value=/data/usenet/incomplete" >/dev/null
  echo "[sabnzbd-api] Download dirs configured"

  # --- Watch folder ---
  api_call "mode=set_config&section=misc&keyword=dirscan_dir&value=/data/usenet/watch" >/dev/null
  api_call "mode=set_config&section=misc&keyword=dirscan_speed&value=5" >/dev/null
  echo "[sabnzbd-api] Watch folder configured"

  # --- Categories ---
  api_call "mode=set_config&section=categories&keyword=tv-sonarr&dir=/data/usenet/tv" >/dev/null
  api_call "mode=set_config&section=categories&keyword=radarr&dir=/data/usenet/movies" >/dev/null
  api_call "mode=set_config&section=categories&keyword=lidarr&dir=/data/usenet/music" >/dev/null
  echo "[sabnzbd-api] Categories configured"

  # --- Web UI auth ---
  if [ -n "${SERVICES_ADMIN_PASSWORD:-}" ]; then
    api_call "mode=set_config&section=misc&keyword=username&value=admin" >/dev/null
    api_call "mode=set_config&section=misc&keyword=password&value=${SERVICES_ADMIN_PASSWORD}" >/dev/null
    echo "[sabnzbd-api] Auth configured"
  fi

  # --- Usenet servers (only add if not already configured) ---
  CURRENT=$(api_call "mode=get_config&section=servers")

  if ! echo "$CURRENT" | grep -q "news.newshosting.com"; then
    PARAMS="mode=set_config&section=servers&keyword=news.newshosting.com"
    PARAMS="${PARAMS}&name=news.newshosting.com"
    PARAMS="${PARAMS}&displayname=newshosting"
    PARAMS="${PARAMS}&host=news.newshosting.com"
    PARAMS="${PARAMS}&port=563"
    PARAMS="${PARAMS}&ssl=1"
    PARAMS="${PARAMS}&username=${NEWSHOSTING_USERNAME}"
    PARAMS="${PARAMS}&password=${NEWSHOSTING_PASSWORD}"
    PARAMS="${PARAMS}&connections=${NEWSHOSTING_CONNECTIONS}"
    PARAMS="${PARAMS}&priority=0"
    PARAMS="${PARAMS}&enable=1&ssl_verify=2&retention=0"
    api_call "$PARAMS" >/dev/null
    echo "[sabnzbd-api] Added newshosting server"
  fi

  if ! echo "$CURRENT" | grep -q "news.giganews.com"; then
    PARAMS="mode=set_config&section=servers&keyword=news.giganews.com"
    PARAMS="${PARAMS}&name=news.giganews.com"
    PARAMS="${PARAMS}&displayname=giganews"
    PARAMS="${PARAMS}&host=news.giganews.com"
    PARAMS="${PARAMS}&port=563"
    PARAMS="${PARAMS}&ssl=1"
    PARAMS="${PARAMS}&username=${GIGANEWS_USERNAME}"
    PARAMS="${PARAMS}&password=${GIGANEWS_PASSWORD}"
    PARAMS="${PARAMS}&connections=${GIGANEWS_CONNECTIONS}"
    PARAMS="${PARAMS}&priority=0"
    PARAMS="${PARAMS}&enable=1&ssl_verify=2&retention=0"
    api_call "$PARAMS" >/dev/null
    echo "[sabnzbd-api] Added giganews server"
  fi

  echo "[sabnzbd-api] Configuration complete"
) &

exit 0