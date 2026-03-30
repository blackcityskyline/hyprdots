#!/usr/bin/env bash

# ~/.config/rofi/finder/finder_warmup.sh
# exec-once = ~/.config/rofi/finder/finder_warmup.sh

FINDER="$HOME/.config/rofi/finder/rofi-finder"
GREP="$HOME/.config/rofi/finder/rofi-grep"

sleep 4

ROFI_OUTSIDE=1 bash "$FINDER" --build-cache

ROFI_OUTSIDE=1 bash "$GREP" --build-index
