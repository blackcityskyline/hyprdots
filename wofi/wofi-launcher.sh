#!/usr/bin/env bash
# ~/.config/wofi/wofi-launcher.sh

WOFI_DIR="$HOME/.config/wofi"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wofi-launcher"
HISTORY_FILE="$CACHE_DIR/history"
PINS_FILE="$CACHE_DIR/pins"

mkdir -p "$CACHE_DIR"
touch "$HISTORY_FILE" "$PINS_FILE"

TERMINAL="alacritty"

declare -A ENGINES=(
  ["g"]="https://www.google.com/search?q="
  ["yt"]="https://www.youtube.com/results?search_query="
  ["gh"]="https://github.com/search?q="
  ["ddg"]="https://duckduckgo.com/?q="
  ["wiki"]="https://en.wikipedia.org/w/index.php?search="
  ["aur"]="https://aur.archlinux.org/packages/?K="
  ["rd"]="https://www.reddit.com/search/?q="
  ["maps"]="https://www.google.com/maps/search/"
)

wofi_run() {
  wofi --conf "$WOFI_DIR/config" --style "$WOFI_DIR/style.css" "$@"
}

encode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

hist_add() {
  grep -vxF "$1" "$HISTORY_FILE" | head -99 > "$HISTORY_FILE.tmp"
  { echo "$1"; cat "$HISTORY_FILE.tmp"; } > "$HISTORY_FILE"
  rm -f "$HISTORY_FILE.tmp"
}

# ── Mode: Apps (native drun — wofi handles icons) ─────────────────────────────
mode_apps() {
  # Pinned shown first via frecency workaround: pre-populate cache with pins
  wofi_run --show drun --prompt "󰣆  Apps"
}

# ── Mode: Run / Search / Calc ─────────────────────────────────────────────────
mode_run() {
  local hints
  hints="$(printf '%s\n' \
    "󰖟  g: …        Google" \
    "󰖟  yt: …       YouTube" \
    "󰖟  gh: …       GitHub" \
    "󰖟  wiki: …     Wikipedia" \
    "󰖟  aur: …      AUR" \
    "󰖟  ddg: …      DuckDuckGo" \
    "󰃬  = 2+2       Calculator → clipboard" \
    "󰆍  > cmd       Shell command" \
    "󰣀  @host       SSH")"

  local sel
  sel=$(echo "$hints" | wofi_run --dmenu --prompt "󰆍  Run")
  [[ -z "$sel" ]] && return

  # Strip icon prefix
  local raw="${sel#* }"
  raw="${raw%%   *}"   # trim hint description
  raw="${raw# }"

  # If user typed something not matching hints — use raw input directly
  # (wofi dmenu returns typed text if no match selected)
  _handle "$raw"
}

# ── Mode: History ─────────────────────────────────────────────────────────────
mode_history() {
  local sel
  sel=$(cat "$HISTORY_FILE" | wofi_run --dmenu --prompt "󰋚  History")
  [[ -z "$sel" ]] && return
  _handle "$sel"
}

# ── Mode: Files ───────────────────────────────────────────────────────────────
mode_files() {
  local sel
  sel=$(find "$HOME" -maxdepth 4 -not -path "*/\.*" 2>/dev/null \
    | wofi_run --dmenu --prompt "󰈔  Files")
  [[ -z "$sel" ]] && return
  hist_add "$sel"
  xdg-open "$sel" &>/dev/null &
}

# ── Mode: Pins ────────────────────────────────────────────────────────────────
mode_pins() {
  # Use drun but pre-filter to pinned apps via dmenu of app names
  local sel
  sel=$(cat "$PINS_FILE" | wofi_run --dmenu --prompt "󰐃  Pinned")
  [[ -z "$sel" ]] && return
  # Launch by name — find Exec in .desktop
  local exec_cmd
  exec_cmd=$(grep -rl "^Name=$sel$" /usr/share/applications ~/.local/share/applications 2>/dev/null \
    | head -1 | xargs grep "^Exec=" 2>/dev/null | head -1 | cut -d= -f2- \
    | sed 's/ *%[a-zA-Z]//g')
  [[ -n "$exec_cmd" ]] && eval "$exec_cmd" &>/dev/null &
}

mode_pin_toggle() {
  local sel
  sel=$(wofi_run --show drun --prompt "󰐃  Pin app" \
    | awk '{print $1}')
  [[ -z "$sel" ]] && return
  if grep -qxF "$sel" "$PINS_FILE"; then
    grep -vxF "$sel" "$PINS_FILE" > "$PINS_FILE.tmp"
    mv "$PINS_FILE.tmp" "$PINS_FILE"
    notify-send "Launcher" "Unpinned: $sel" -t 1500
  else
    echo "$sel" >> "$PINS_FILE"
    notify-send "Launcher" "Pinned: $sel" -t 1500
  fi
}

# ── Query handler ─────────────────────────────────────────────────────────────
_handle() {
  local q="$1"
  [[ -z "$q" ]] && return

  # Calc
  if [[ "$q" =~ ^=[[:space:]]?(.+) ]]; then
    local expr="${BASH_REMATCH[1]// /}"
    local res
    res=$(echo "scale=10; $expr" | bc -l 2>/dev/null | sed 's/\.?0*$//')
    [[ -n "$res" ]] && {
      echo -n "$res" | wl-copy 2>/dev/null
      notify-send "= $res" "$expr" -t 2000
      hist_add "= $expr → $res"
    }
    return
  fi

  # Shell cmd
  if [[ "$q" =~ ^\>[[:space:]]?(.+) ]]; then
    local cmd="${BASH_REMATCH[1]}"
    hist_add "> $cmd"
    eval "$cmd" &>/dev/null &
    return
  fi

  # SSH
  if [[ "$q" =~ ^@(.+) ]] || [[ "$q" =~ ^ssh[[:space:]](.+) ]]; then
    local host="${BASH_REMATCH[1]}"
    hist_add "ssh $host"
    "$TERMINAL" -e ssh "$host" &
    return
  fi

  # URL
  if [[ "$q" =~ ^https?:// ]] || [[ "$q" =~ ^www\. ]]; then
    hist_add "$q"
    xdg-open "$q" &>/dev/null &
    return
  fi

  # Prefixed search
  if [[ "$q" =~ ^([a-z]+):[[:space:]]?(.+) ]]; then
    local prefix="${BASH_REMATCH[1]}" query="${BASH_REMATCH[2]}"
    local url="${ENGINES[$prefix]}"
    if [[ -n "$url" ]]; then
      hist_add "$q"
      xdg-open "${url}$(encode "$query")" &>/dev/null &
      return
    fi
  fi

  # Default: Google
  hist_add "$q"
  xdg-open "https://www.google.com/search?q=$(encode "$q")" &>/dev/null &
}

# ── Mode switcher ────────────────────────────────────────────────────────────
mode_select() {
  local sel
  sel=
  case "$sel" in
    *"Apps"*)    mode_apps ;;
    *"Run"*)     mode_run ;;
    *"Files"*)   mode_files ;;
    *"History"*) mode_history ;;
    *"Pins"*)    mode_pins ;;
  esac
}

# ── Entry ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --apps)        mode_apps ;;
  --run)         mode_run ;;
  --history)     mode_history ;;
  --files)       mode_files ;;
  --pins)        mode_pins ;;
  --pin-toggle)  mode_pin_toggle ;;
  *)             mode_select ;;
esac
