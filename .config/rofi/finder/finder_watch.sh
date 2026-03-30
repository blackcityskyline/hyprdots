#!/usr/bin/env bash

# ~/.config/rofi/finder/finder_watch.sh
# Следит за SEARCH_DIRS и инвалидирует кэш при изменениях
# exec-once = ~/.config/rofi/finder/finder_watch.sh

CACHE_DIR="/tmp/rofi-finder-cache"
ROOT_KEY="${HOME//\//_}"

SEARCH_DIRS=(
  "$HOME/.config"
  "$HOME/Documents"
  "$HOME/Desktop"
  "$HOME/Git"
  "$HOME/notes"
  "$HOME/bin"
  "$HOME/apps"
  "$HOME/Downloads"
  "/etc"
)

if ! command -v inotifywait &>/dev/null; then
  exit 0
fi

existing_dirs=()
for d in "${SEARCH_DIRS[@]}"; do
  [[ -d "$d" ]] && existing_dirs+=("$d")
done

inotifywait -m -r \
  -e create,delete,move,modify,attrib \
  --format '%w' \
  "${existing_dirs[@]}" 2>/dev/null |
  while read -r changed_dir; do
    rm -f "$CACHE_DIR/$ROOT_KEY"
    ckey="${changed_dir%/}"
    ckey="${ckey//\//_}"
    rm -f "$CACHE_DIR/$ckey"
  done
