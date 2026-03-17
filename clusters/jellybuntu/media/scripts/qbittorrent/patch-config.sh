#!/bin/bash
# Patches qBittorrent config with download paths, categories, and localhost
# auth bypass on every start. Runs as a LSIO custom-cont-init.d script.
#
# First boot: qBittorrent.conf doesn't exist yet. We skip patching and let
# qBittorrent create its default config. Patches apply on subsequent restarts.

set -euo pipefail

CONF="/config/qBittorrent/qBittorrent.conf"
CATS="/config/qBittorrent/categories.json"

if [ ! -f "$CONF" ]; then
  echo "[qbittorrent-init] No config found (first boot) — skipping patches"
  exit 0
fi

python3 << 'PYEOF'
import configparser
import json
import os

conf = "/config/qBittorrent/qBittorrent.conf"
cats = "/config/qBittorrent/categories.json"

# --- Patch qBittorrent.conf ---
config = configparser.RawConfigParser()
config.optionxform = str  # preserve case (qBittorrent uses mixed case keys)
config.read(conf)

for section in ["BitTorrent", "Preferences"]:
    if not config.has_section(section):
        config.add_section(section)

# Download paths (NAS via NFS, no ramdisk)
config.set("BitTorrent", r"Session\DefaultSavePath", "/data/torrents/")
config.set("BitTorrent", r"Session\TempPath", "/data/torrents/incomplete/")
config.set("BitTorrent", r"Session\TempPathEnabled", "true")
config.set("Preferences", r"Downloads\SavePath", "/data/torrents/")
config.set("Preferences", r"Downloads\TempPath", "/data/torrents/incomplete/")
config.set("Preferences", r"Downloads\TempPathEnabled", "true")

# Bypass auth for localhost (Gluetun port sync uses localhost API)
config.set("Preferences", r"WebUI\LocalHostAuth", "false")

with open(conf, "w") as f:
    config.write(f, space_around_delimiters=False)

print("[qbittorrent-init] Config patched")

# --- Write categories.json ---
categories = {
    "tv-sonarr": {"save_path": "/data/torrents/tv-sonarr"},
    "radarr": {"save_path": "/data/torrents/radarr"},
    "lidarr": {"save_path": "/data/torrents/music"}
}

os.makedirs(os.path.dirname(cats), exist_ok=True)
with open(cats, "w") as f:
    json.dump(categories, f, indent=2)
    f.write("\n")

print("[qbittorrent-init] Categories written")
PYEOF