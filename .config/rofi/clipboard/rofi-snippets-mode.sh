#!/bin/bash
# Rofi script mode для сниппетов
# ROFI_RETV=0  — показать список
# ROFI_RETV=1  — выбран элемент → копировать
# ROFI_RETV=2  — кастомный ввод: +text или +tag: text → добавить сниппет
# ROFI_RETV=10 — ctrl+d → удалить сниппет
# ROFI_RETV=11 — ctrl+e → открыть snippets.txt в редакторе

: "${TERMINAL:=alacritty}"
: "${EDITOR_CMD:=nvim}"
SNIPPETS_FILE="$HOME/.config/rofi/clipboard/snippets.txt"
[ -f "$SNIPPETS_FILE" ] || touch "$SNIPPETS_FILE"

if [ "$ROFI_RETV" = "0" ]; then
    echo "  + text  |  + tag: text"
    cat "$SNIPPETS_FILE"

elif [ "$ROFI_RETV" = "2" ]; then
    if [[ "$1" == +* ]]; then
        INPUT=$(echo "${1:1}" | sed 's/^ *//')
        if [[ "$INPUT" =~ ^([a-zA-Z0-9_-]+):\ *(.+)$ ]]; then
            TAG="${BASH_REMATCH[1]}"
            TEXT="${BASH_REMATCH[2]}"
            SNIPPET="[$TAG] $TEXT"
        else
            SNIPPET="$INPUT"
        fi
        if [ -n "$SNIPPET" ]; then
            echo "$SNIPPET" >> "$SNIPPETS_FILE"
            echo -n "$SNIPPET" | wl-copy
        fi
    fi

elif [ "$ROFI_RETV" = "1" ]; then
    echo -n "$1" | wl-copy

elif [ "$ROFI_RETV" = "10" ]; then
    # Удалить выбранный сниппет
    ESCAPED=$(printf '%s\n' "$1" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i "/^${ESCAPED}$/d" "$SNIPPETS_FILE"
    echo "  + text  |  + tag: text"
    cat "$SNIPPETS_FILE"

elif [ "$ROFI_RETV" = "11" ]; then
    # Открыть snippets.txt в редакторе
    setsid "$TERMINAL" -e "$EDITOR_CMD" "$SNIPPETS_FILE" </dev/null >/dev/null 2>&1 &
fi
