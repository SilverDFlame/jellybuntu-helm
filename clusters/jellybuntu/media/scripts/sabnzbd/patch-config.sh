#!/bin/bash
# Patches sabnzbd.ini on every container start.
# First boot: waits for SABnzbd to generate config, patches, restarts via s6.

CONFIG="/config/sabnzbd.ini"
API_KEY="${SABNZBD_API_KEY:-}"

patch_config() {
  sed -i 's/^host_whitelist *=.*/host_whitelist = sabnzbd.elysium.industries, sabnzbd, localhost, 127.0.0.1/' "$CONFIG"
  sed -i 's/^local_ranges *=.*/local_ranges = 10.42.0.0\/16, 10.43.0.0\/16, 100.64.0.0\/10, 192.168.30.0\/24/' "$CONFIG"

  if [ -n "$API_KEY" ]; then
    sed -i "s/^api_key *=.*/api_key = $API_KEY/" "$CONFIG"
  fi

  sed -i 's|^download_dir *=.*|download_dir = /data/usenet/incomplete|' "$CONFIG"
  sed -i 's|^complete_dir *=.*|complete_dir = /data/usenet|' "$CONFIG"
  sed -i 's/^bandwidth_max *=.*/bandwidth_max = 40M/' "$CONFIG"
  sed -i 's/^fulldisk_autoresume *=.*/fulldisk_autoresume = 1/' "$CONFIG"
  sed -i 's/^download_free *=.*/download_free = 3G/' "$CONFIG"
  sed -i 's/^top_only *=.*/top_only = 1/' "$CONFIG"
  sed -i 's/^pre_check *=.*/pre_check = 1/' "$CONFIG"
  sed -i 's/^enable_unrar *=.*/enable_unrar = 0/' "$CONFIG"
  sed -i 's/^enable_7zip *=.*/enable_7zip = 0/' "$CONFIG"
  sed -i 's/^direct_unpack *=.*/direct_unpack = 0/' "$CONFIG"

  echo "[sabnzbd-init] Config patched successfully"
}

if [ -f "$CONFIG" ]; then
  patch_config
else
  echo "[sabnzbd-init] First boot — will patch after config is generated"
  (
    while [ ! -f "$CONFIG" ]; do sleep 2; done
    sleep 3
    patch_config
    echo "[sabnzbd-init] Restarting SABnzbd with patched config..."
    s6-svc -r /var/run/service/svc-sabnzbd
  ) &
fi