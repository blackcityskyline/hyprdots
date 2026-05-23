#!/bin/bash
# ~/bin/swaync/toggle-widgets.sh
# Toggle some swaync widgets

SWAYNC_DIR="$HOME/.config/swaync"
CONFIG="$SWAYNC_DIR/config.json"
CONFIG_FULL="$SWAYNC_DIR/config-full.json"
CONFIG_COMPACT="$SWAYNC_DIR/config-compact.json"
STATE_FILE="/tmp/swaync-compact"

if [ ! -f "$CONFIG_FULL" ] || [ ! -f "$CONFIG_COMPACT" ]; then
  notify-send "swaync" "Config files missing"
  exit 1
fi

if [ -f "$STATE_FILE" ]; then
  # If compact  →  unfold
  cp "$CONFIG_FULL" "$CONFIG"
  rm -f "$STATE_FILE"
else
  # If full → fold
  cp "$CONFIG_COMPACT" "$CONFIG"
  touch "$STATE_FILE"
fi

swaync-client --reload-config
