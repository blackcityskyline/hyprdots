#!/usr/bin/env bash

player_status=$(playerctl --player=kew,playerctld,%any status 2>/dev/null)

if [ "$player_status" = "Playing" ] || [ "$player_status" = "Paused" ]; then
  artist=$(playerctl --player=kew,playerctld,%any metadata artist 2>/dev/null || echo "")
  title=$(playerctl --player=kew,playerctld,%any metadata title 2>/dev/null || echo "?")

  # strip quotes and extra whitespace
  artist=$(echo "$artist" | sed 's/["'"'"']//g' | xargs)
  title=$(echo "$title" | sed 's/["'"'"']//g' | xargs)

  # build full text
  if [ -z "$artist" ]; then
    full_text="$title"
  else
    full_text="$artist - $title"
  fi

  MAX_LENGTH=20

  if [ ${#full_text} -le $MAX_LENGTH ]; then
    display_text="$full_text"
  else
    # scrolling text — shift by 1 char per second
    current_time=$(date +%s)
    separator=" • "
    extended_text="$full_text$separator$full_text"
    text_length=${#full_text}
    offset=$((current_time % (text_length + ${#separator})))
    display_text="${extended_text:offset:MAX_LENGTH}"

    # wrap around if substring is shorter than max
    if [ ${#display_text} -lt $MAX_LENGTH ]; then
      remaining=$((MAX_LENGTH - ${#display_text}))
      display_text="$display_text${extended_text:0:remaining}"
    fi
  fi

  # truncated variants for short display
  if [ ${#artist} -gt 10 ]; then
    artist_short="${artist:0:10}…"
  else
    artist_short="$artist"
  fi
  if [ ${#title} -gt 15 ]; then
    title_short="${title:0:15}…"
  else
    title_short="$title"
  fi

  if [ -z "$artist" ]; then
    short_text="$title_short"
  else
    short_text="$artist_short - $title_short"
  fi

  if [ "$player_status" = "Playing" ]; then
    icon=""
  else
    icon=""
  fi

  echo "{\"text\": \"$icon $display_text\", \"class\": \"$player_status\", \"tooltip\": \"$artist - $title\\nClick: Play/Pause | Scroll: Next/Prev\"}"
else
  echo "{\"text\": \"\", \"class\": \"stopped\", \"tooltip\": \"No active media player\"}"
fi
