#!/bin/bash
cliphist list | rofi -dmenu \
  -config ~/.config/rofi/clipboard/clipboard.rasi \
  -no-show-match \
  -no-custom \
  -i | cliphist decode | wl-copy
