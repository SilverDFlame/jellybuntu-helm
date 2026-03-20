#!/bin/sh
# Watch Gluetun port file → sync to qBittorrent API
# Runs as a sidecar container. Uses inotifywait to detect port changes.
#
# Guards against Gluetun's bindPort keepalive cycle, which periodically
# clears and rewrites the port file with the same value (see gluetun#2812).

PORT_FILE="/tmp/gluetun/forwarded_port"
QBT_URL="http://127.0.0.1:8080"
CURRENT_PORT=""

read_port() {
  [ -f "$PORT_FILE" ] || return 1
  PORT=$(cat "$PORT_FILE" | tr -d '[:space:]')
  # Validate: must be a number in valid port range
  case "$PORT" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || return 1
  echo "$PORT"
}

set_port() {
  wget -qO- --post-data "json={\"listen_port\":$1}" \
    --header="Referer: $QBT_URL" \
    "$QBT_URL/api/v2/app/setPreferences" >/dev/null 2>&1
}

apply_port() {
  NEW_PORT=$(read_port) || return 1
  if [ "$NEW_PORT" = "$CURRENT_PORT" ]; then
    echo "[port-sync] Port unchanged ($NEW_PORT) — skipping"
    return 0
  fi
  if set_port "$NEW_PORT"; then
    CURRENT_PORT="$NEW_PORT"
    echo "[port-sync] Set port to $NEW_PORT"
  else
    return 1
  fi
}

while true; do
  if [ -f "$PORT_FILE" ]; then
    # Retry until qBittorrent API is ready and port is set
    until apply_port; do
      echo "[port-sync] Waiting for qBittorrent API or valid port..."
      sleep 5
    done

    # Watch for port changes (blocks until file is written)
    inotifywait -mq -e close_write "$PORT_FILE" | while read _; do
      if ! NEW_PORT=$(read_port); then
        echo "[port-sync] Port file empty or invalid — ignoring"
      elif [ "$NEW_PORT" = "$CURRENT_PORT" ]; then
        echo "[port-sync] Port unchanged ($NEW_PORT) — skipping"
      elif set_port "$NEW_PORT"; then
        CURRENT_PORT="$NEW_PORT"
        echo "[port-sync] Set port to $NEW_PORT"
      fi
    done
  else
    echo "[port-sync] Waiting for port file..."
    sleep 10
  fi
done