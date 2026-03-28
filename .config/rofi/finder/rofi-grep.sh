#!/usr/bin/env bash

# ~/.config/rofi/finder/grep.sh
# Enter        → открыть файл в nvim
# ctrl+y       → скопировать путь файла
# Enter (custom input, 3+ chars) → живой поиск через rg
# --build-index → построить индекс вручную

: "${TERMINAL:=alacritty}"
: "${EDITOR_CMD:=nvim}"
: "${MAX_GREP_RESULTS:=100000}"
: "${GREP_CACHE_TTL:=600}"

if [ -z "$ROFI_OUTSIDE" ]; then
  exec rofi \
    -show grep \
    -modi "grep:$0" \
    -show grep -config ~/.config/rofi/finder/finder.rasi
fi

export ROFI_OUTSIDE=1

CACHE_DIR="/tmp/rofi-finder-cache"
GREP_CACHE="$CACHE_DIR/grep_index"
mkdir -p "$CACHE_DIR"

if ! command -v rg &>/dev/null; then
  printf '\x00prompt\x1frg not found\n'
  exit 1
fi

SEARCH_DIRS=(
  "$HOME/.config"
  "$HOME/.ssh"
  "$HOME/.local/share/applications"
  "$HOME/apps"
  "$HOME/bin"
  "$HOME/Documents"
  "$HOME/Desktop"
  "$HOME/Git"
  "$HOME/Downloads"
  "$HOME/notes"
  "$HOME/Public"
)

RG_GLOBS=(
  -g '*.{txt,md,markdown,rst,conf,ini,cfg,env}'
  -g '*.{json,jsonc,yaml,yml,toml,xml,html,htm,css,scss,sass}'
  -g '*.{c,cpp,h,hpp,py,sh,bash,zsh,fish,lua,vim}'
  -g '*.{rs,go,js,mjs,ts,jsx,tsx,svelte,vue,rb,php}'
  -g '*.{el,hs,ml,ex,exs,dart,kt,swift,java,cs,r,sql,tf,hcl}'
)

RG_EXCLUDES=(
  --glob='!**/.git/**'
  --glob='!**/node_modules/**'
  --glob='!**/__pycache__/**'
  --glob='!**/*.log'
  --glob='!**/BraveSoftware/**'
  --glob='!**/chromium/**'
  --glob='!**/chromium-backup/**'
  --glob='!**/google-chrome/**'
  --glob='!**/google-chrome-backup/**'
  --glob='!**/vivaldi/**'
  --glob='!**/vivaldi-backup/**'
  --glob='!**/microsoftedge/**'
  --glob='!**/Min/**'
  --glob='!**/gtk-2.0/**'
  --glob='!**/gtk-3.0/**'
  --glob='!**/gtk-4.0/**'
  --glob='!**/Kvantum/**'
  --glob='!**/KDE/**'
  --glob='!**/plasma*'
  --glob='!**/kwin*'
  --glob='!**/kde*'
  --glob='!**/heroic/**'
  --glob='!**/obs-studio/**'
  --glob='!**/sunshine/**'
  --glob='!**/nvim/lazy/**'
  --glob='!**/nvim/mason/**'
  --glob='!**/jdhao/**'
  --glob='!**/Bitwarden/**'
  --glob='!**/Session/**'
  --glob='!**/Session-development/**'
  --glob='!**/pulse/**'
  --glob='!**/wal/**'
  --glob='!**/fontconfig/**'
  --glob='!**/.zcompdump*'
)

# ── Построить индекс ──────────────────────────────────────────────────────────
build_grep_index() {
  local prefix="${HOME%/}/"
  local existing=()
  for d in "${SEARCH_DIRS[@]}"; do
    [[ -e "$d" ]] && existing+=("$d")
  done

  find "$HOME" -maxdepth 1 -type f 2>/dev/null | while IFS= read -r f; do
    file --mime-type -b "$f" 2>/dev/null | grep -q "^text/" || continue
    local rel="${f#"$prefix"}"
    rg --line-number --no-heading --color=never \
      --max-filesize=300K --max-columns=200 \
      "" "$f" 2>/dev/null | while IFS= read -r raw; do
      local lineno="${raw%%:*}" content="${raw#*:}"
      printf '%s:%s: %s\x00info\x1f%s\x1f%s\n' \
        "$rel" "$lineno" "${content:0:120}" "$f" "$lineno"
    done
  done

  rg --hidden --line-number --no-heading --color=never \
    "${RG_GLOBS[@]}" "${RG_EXCLUDES[@]}" \
    --max-filesize=100K --max-columns=200 \
    "" "${existing[@]}" 2>/dev/null | \
  head -"$MAX_GREP_RESULTS" | \
  while IFS= read -r raw; do
    local file="${raw%%:*}" rest="${raw#*:}"
    local lineno="${rest%%:*}" content="${rest#*:}"
    local rel="${file#"$prefix"}"
    printf '%s:%s: %s\x00info\x1f%s\x1f%s\n' \
      "$rel" "$lineno" "${content:0:120}" "$file" "$lineno"
  done
}

# ── Живой поиск через rg ──────────────────────────────────────────────────────
live_search() {
  local query="$1"
  local prefix="${HOME%/}/"
  local existing=()
  for d in "${SEARCH_DIRS[@]}"; do
    [[ -e "$d" ]] && existing+=("$d")
  done

  printf '\x00prompt\x1f GREP: %s\n' "$query"
  printf '\x00message\x1f<span foreground="#7aa2f7"> live rg</span>  <span foreground="#565f89" size="small">Enter → открыть  |  Esc → назад к индексу</span>\n'

  rg --hidden --line-number --no-heading --color=never --smart-case \
    "${RG_GLOBS[@]}" "${RG_EXCLUDES[@]}" \
    --max-filesize=100K --max-columns=200 \
    "$query" "${existing[@]}" 2>/dev/null | \
  head -200 | \
  while IFS= read -r raw; do
    local file="${raw%%:*}" rest="${raw#*:}"
    local lineno="${rest%%:*}" content="${rest#*:}"
    local rel="${file#"$prefix"}"
    printf '%s:%s: %s\x00info\x1f%s\x1f%s\n' \
      "$rel" "$lineno" "${content:0:120}" "$file" "$lineno"
  done
}

# ── Получить индекс ───────────────────────────────────────────────────────────
get_grep_index() {
  if [[ -f "$GREP_CACHE" ]]; then
    local mtime now age
    printf -v now '%(%s)T' -1
    mtime="$(stat -c %Y "$GREP_CACHE" 2>/dev/null)" || mtime=0
    age=$(( now - mtime ))
    cat "$GREP_CACHE"
    if (( age >= GREP_CACHE_TTL )); then
      ( build_grep_index > "$GREP_CACHE" ) &
    fi
  else
    ( build_grep_index > "$GREP_CACHE" ) &
    printf '\x00message\x1f<span foreground="#7aa2f7">⟳ Индексирую в фоне...</span>  <span foreground="#565f89" size="small">Закрой и открой через ~15 сек</span>\n'
  fi
}

# ── Вывод меню ────────────────────────────────────────────────────────────────
print_menu() {
  printf '\x00prompt\x1f GREP\n'
  printf '\x00message\x1f<span foreground="#565f89" size="small">fuzzy по индексу  |  Enter на пустой строке → live rg (3+ символов)</span>\n'
  get_grep_index
}

# ── Хелперы ───────────────────────────────────────────────────────────────────
parse_info() {
  if [[ -n "$ROFI_INFO" ]]; then
    IFS=$'\x1f' read -ra _info <<< "$ROFI_INFO"
    SELECTED_FILE="${_info[0]}"
    SELECTED_LINE="${_info[1]:-1}"
  else
    SELECTED_FILE=""
    SELECTED_LINE="1"
  fi
}

open_at_line() {
  [[ ! -f "$1" ]] && return 1
  setsid "$TERMINAL" -e "$EDITOR_CMD" +"$2" "$1" </dev/null >/dev/null 2>&1 &
}

copy_path() {
  printf '%s' "$1" | wl-copy 2>/dev/null
  notify-send -t 2000 "" "Путь скопирован: $1"
}

# ── Режим ручной индексации ────────────────────────────────────────────────────
if [[ "$1" == "--build-index" ]]; then
  build_grep_index > "$GREP_CACHE"
  exit 0
fi

# ── Главная логика ────────────────────────────────────────────────────────────
case "${ROFI_RETV:-0}" in
0)
  print_menu
  ;;
1)
  parse_info
  if [[ -n "$SELECTED_FILE" && -f "$SELECTED_FILE" ]]; then
    open_at_line "$SELECTED_FILE" "${SELECTED_LINE:-1}"
  fi
  print_menu
  ;;
2)
  # Кастомный ввод — живой поиск если 3+ символов
  query="$1"
  if [[ ${#query} -ge 3 ]]; then
    live_search "$query"
  else
    printf '\x00message\x1f<span foreground="#e0af68">Введи 3+ символа для live поиска</span>\n'
    printf '\x00prompt\x1f GREP\n'
    get_grep_index
  fi
  ;;
10)
  # ctrl+y — скопировать путь
  parse_info
  [[ -n "$SELECTED_FILE" ]] && copy_path "$SELECTED_FILE"
  print_menu
  ;;
*)
  print_menu
  ;;
esac
