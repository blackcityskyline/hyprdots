#!/bin/bash
# Rofi script mode для клипборда
# ROFI_RETV=0  — показать список
# ROFI_RETV=1  — выбран элемент → декодировать и скопировать
# ROFI_RETV=10 — ctrl+d → удалить из истории

if [ "$ROFI_RETV" = "0" ]; then
    cliphist list

elif [ "$ROFI_RETV" = "1" ]; then
    echo "$1" | cliphist decode | wl-copy

elif [ "$ROFI_RETV" = "10" ]; then
    echo "$1" | cliphist delete
    cliphist list
fi
