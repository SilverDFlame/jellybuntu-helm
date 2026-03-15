#!/bin/bash
# Patches sabnzbd.ini with required settings on every container start.
# Runs as a LSIO custom-cont-init.d script (root, before service starts).
#
# First boot: sabnzbd.ini doesn't exist yet. We launch a background process
# that waits for SABnzbd to generate its default config, patches it, and
# restarts SABnzbd via s6. Subsequent boots patch the existing config directly.

set -euo pipefail

CONFIG="/config/sabnzbd.ini"
API_KEY="${SABNZBD_API_KEY:-}"

patch_config() {
  python3 << 'PYEOF'
import configparser
import os

cfg = "/config/sabnzbd.ini"
api_key = os.environ.get("SABNZBD_API_KEY", "")

config = configparser.RawConfigParser()
config.optionxform = str  # preserve case
config.read(cfg)

if not config.has_section("misc"):
    config.add_section("misc")

# --- Access control ---
config.set("misc", "host_whitelist",
    "sabnzbd.elysium.industries, sabnzbd, localhost, 127.0.0.1")
config.set("misc", "local_ranges",
    "10.42.0.0/16, 10.43.0.0/16, 100.64.0.0/10, 192.168.30.0/24")

# --- API key ---
if api_key:
    config.set("misc", "api_key", api_key)

# --- Download paths (NAS via NFS, no ramdisk) ---
config.set("misc", "download_dir", "/data/usenet/incomplete")
config.set("misc", "complete_dir", "/data/usenet")

# --- Bandwidth limit (40 MB/s) ---
config.set("misc", "bandwidth_max", "40M")

# --- Queue behavior ---
config.set("misc", "fulldisk_autoresume", "1")
config.set("misc", "download_free", "3G")
config.set("misc", "top_only", "1")
config.set("misc", "pre_check", "1")

# --- Disable built-in unpacking (Unpackerr handles extraction) ---
config.set("misc", "enable_unrar", "0")
config.set("misc", "enable_7zip", "0")
config.set("misc", "direct_unpack", "0")

with open(cfg, "w") as f:
    config.write(f)

print("[sabnzbd-init] Config patched successfully")
PYEOF
}

if [ -f "$CONFIG" ]; then
  # Normal path: config exists, patch it before SABnzbd starts
  patch_config
else
  # First boot: wait for SABnzbd to generate config, then patch and restart
  echo "[sabnzbd-init] First boot — will patch config after SABnzbd generates it"
  (
    # Wait for SABnzbd to create its default config
    while [ ! -f "$CONFIG" ]; do
      sleep 2
    done
    # Give SABnzbd a moment to finish writing
    sleep 3

    patch_config
    echo "[sabnzbd-init] Restarting SABnzbd with patched config..."
    s6-svc -r /var/run/service/svc-sabnzbd
  ) &
fi