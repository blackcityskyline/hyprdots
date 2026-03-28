#!/usr/bin/env bash

# ~/.config/rofi/finder/finder_warmup.sh
# exec-once = ~/.config/rofi/finder/finder_warmup.sh

FINDER="$HOME/.config/rofi/finder/finder.sh"
GREP="$HOME/.config/rofi/finder/grep.sh"

# Ждём пока Hyprland и остальные exec-once поднимутся
sleep 4

# Строим finder кэш синхронно — ждём завершения
ROFI_OUTSIDE=1 bash "$FINDER" --build-cache

# Строим grep индекс
ROFI_OUTSIDE=1 bash "$GREP" --build-index
