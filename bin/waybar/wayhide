#!/usr/bin/env bash
# ~/bin/waybar_toggle.sh

if pgrep -x waybar >/dev/null; then
  pkill waybar
else
  waybar &
fi
