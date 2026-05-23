#!/usr/bin/env bash

# Clipboard manager for Waybar
# Shows clipboard history count or current content

CLIPBOARD_FILE="$HOME/.local/share/clipboard_history.txt"
MAX_PREVIEW=40

# Ensure clipboard file exists
mkdir -p "$(dirname "$CLIPBOARD_FILE")"
touch "$CLIPBOARD_FILE"

# Get clipboard content
clip_content=$(wl-paste 2>/dev/null || xclip -o 2>/dev/null || echo "")

# Count history entries
history_count=$(wc -l <"$CLIPBOARD_FILE" 2>/dev/null || echo "0")

# Prepare display
if [ -z "$clip_content" ] || [ "$clip_content" = "" ]; then
  text="󰅍"
  tooltip="Clipboard: Empty"
else
  # Create preview
  preview=$(echo "$clip_content" | head -1 | tr -d '\n' | sed 's/"/\\"/g')
  if [ ${#preview} -gt $MAX_PREVIEW ]; then
    preview="${preview:0:$MAX_PREVIEW}…"
  fi

  text="󰅍"
  tooltip="Clipboard: $preview\nHistory: $history_count items\nClick: Show history\nRight-click: Clear"
fi

# Output JSON
echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\"}"
