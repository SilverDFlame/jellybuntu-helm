#!/bin/sh
# Watch Gluetun port file → sync to qBittorrent API
# Runs as a sidecar container. Uses inotifywait to detect port changes.

PORT_FILE="/tmp/gluetun/forwarded_port"
QBT_URL="http://127.0.0.1:8080"

update_port() {
  PORT=$(cat "$PORT_FILE")
  wget -qO- --post-data "json={\"listen_port\":$PORT}" \
    --header="Referer: $QBT_URL" \
    "$QBT_URL/api/v2/app/setPreferences" >/dev/null 2>&1
}

while true; do
  if [ -f "$PORT_FILE" ]; then
    # Retry until qBittorrent API is ready and port is set
    until update_port; do
      echo "[port-sync] Waiting for qBittorrent API..."
      sleep 5
    done
    echo "[port-sync] Set port to $(cat $PORT_FILE)"

    # Watch for port changes (blocks until file is written)
    inotifywait -mq -e close_write "$PORT_FILE" | while read _; do
      update_port && echo "[port-sync] Set port to $(cat $PORT_FILE)"
    done
  else
    echo "[port-sync] Waiting for port file..."
    sleep 10
  fi
done