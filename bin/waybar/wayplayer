#!/usr/bin/env bash
# Media player status for Waybar

PLAYER="kew,playerctld,%any"
MAX_LENGTH=20

status=$(playerctl --player="$PLAYER" status 2>/dev/null)

if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
  title=$(playerctl --player="$PLAYER" metadata title 2>/dev/null)
  artist=$(playerctl --player="$PLAYER" metadata artist 2>/dev/null)
  text="${title} – ${artist}"
  [[ ${#text} -gt $MAX_LENGTH ]] && text="${text:0:$MAX_LENGTH}..."
  echo " $text"
else
  echo ""
fi
