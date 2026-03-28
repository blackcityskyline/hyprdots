#!/usr/bin/env bash
# Night Shift Settings — rofi menu
# ~/.config/rofi/nightshift/rofi-nightshift_config.sh

set -uo pipefail
export LC_ALL="${LC_ALL:-C.UTF-8}"

# ─── Конфиг ───────────────────────────────────────────────────────────────────
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/nightshift/nightshift.conf"
SCRIPT_PATH="$HOME/.config/rofi/nightshift/rofi-nightshift.sh"
RASI_THEME="$HOME/.config/rofi/network/network.rasi"
MAX_LINES=15

# ─── Иконки ───────────────────────────────────────────────────────────────────
SETTINGS="󰒓" TEMP="󰔏" TIME="󰥔" DURATION="󰔛" MODE="󰖔"
STATUS="󰋼" TOGGLE="󰔡" BACK="󰜺" EXIT="󰿅"

# ─── Инициализация конфига ────────────────────────────────────────────────────
init_config() {
  [[ -f "$CONFIG_FILE" ]] && return 0
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat >"$CONFIG_FILE" <<'CONF'
# Night Shift Configuration
DAY_TEMP=5500
NIGHT_TEMP=3300
DAWN_TIME="14:00"
DUSK_TIME="18:00"
TRANSITION_DURATION=2700
# LAT="53.9"
# LON="27.6"
CONF
}

set_setting() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    sed -i "s|^# *${key}=.*|${key}=${value}|" "$CONFIG_FILE"
    grep -q "^${key}=" "$CONFIG_FILE" || echo "${key}=${value}" >>"$CONFIG_FILE"
  fi
}

comment_setting() {
  sed -i "s|^${1}=|# ${1}=|" "$CONFIG_FILE"
}

notify() {
  command -v notify-send &>/dev/null &&
    notify-send "Night Shift" "$1" -t "${2:-2000}" 2>/dev/null || true
  echo "$1" >&2
}

check_script() {
  [[ -f "$SCRIPT_PATH" ]] || {
    notify "Error: backend not found at $SCRIPT_PATH" 5000
    exit 1
  }
}

restart_if_running() {
  pgrep -f "wlsunset" >/dev/null && bash "$SCRIPT_PATH" restart
}

# ─── Rofi хелперы ─────────────────────────────────────────────────────────────
_rofi_base() {
  local prompt="$1" n="$2"
  shift 2
  local -a cmd=(rofi -dmenu -p "$prompt")
  [[ -f "$RASI_THEME" ]] && cmd+=(-theme "$RASI_THEME")
  cmd+=(-theme-str "listview { lines: ${n}; }")
  cmd+=("$@")
  "${cmd[@]}"
}

menu() {
  local prompt="$1" content="$2"
  local rendered
  rendered=$(printf '%b' "$content")
  local n
  n=$(printf '%s' "$rendered" | awk 'NF' | wc -l)
  [[ $n -lt 1 ]] && n=1
  [[ $n -gt $MAX_LINES ]] && n=$MAX_LINES
  printf '%s\n' "$rendered" | _rofi_base "$prompt" "$n" 2>/dev/null || true
}

input_menu() {
  local prompt="$1" default="$2"
  local -a cmd=(rofi -dmenu -p "$prompt")
  [[ -f "$RASI_THEME" ]] && cmd+=(-theme "$RASI_THEME")
  cmd+=(-theme-str "listview { lines: 1; }")
  printf '%s\n' "$default" | "${cmd[@]}" 2>/dev/null || true
}

# ─── Главное меню ─────────────────────────────────────────────────────────────
main_menu() {
  source "$CONFIG_FILE"
  local status_text="OFF"
  pgrep -f "wlsunset" >/dev/null && status_text="ON"

  local items=""
  items+="$STATUS Status: $status_text\n"
  items+="$TOGGLE On/Off Night Shift\n"
  items+="$TEMP Temp: ${DAY_TEMP}K / ${NIGHT_TEMP}K\n"
  items+="$TIME Time: ${DAWN_TIME} - ${DUSK_TIME}\n"
  items+="$DURATION Transition: $((TRANSITION_DURATION / 60)) min\n"
  items+="$MODE Mode\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Night Shift:" "$items")
  case "$ch" in
  *"Exit"* | "") exit 0 ;;
  *"On/Off"*)
    bash "$SCRIPT_PATH" toggle
    sleep 1
    main_menu
    ;;
  *"Temp:"*) temperature_menu ;;
  *"Time:"*) time_menu ;;
  *"Transition:"*) duration_menu ;;
  *"Mode"*) mode_menu ;;
  *) main_menu ;;
  esac
}

# ─── Температура ──────────────────────────────────────────────────────────────
temperature_menu() {
  source "$CONFIG_FILE"
  local items=""
  items+="$BACK Back\n"
  items+="$TEMP Day: ${DAY_TEMP}K\n"
  items+="$TEMP Night: ${NIGHT_TEMP}K\n"
  items+="$SETTINGS Presets\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Temperature:" "$items")
  case "$ch" in
  *"Exit"* | "") exit 0 ;;
  *"Back"*) main_menu ;;
  *"Day"*)
    local new_temp
    new_temp=$(input_menu "Day temperature (K):" "$DAY_TEMP")
    if [[ -n "$new_temp" && "$new_temp" =~ ^[0-9]+$ ]]; then
      set_setting "DAY_TEMP" "$new_temp"
      notify "Day temperature: ${new_temp}K"
      restart_if_running
    fi
    temperature_menu
    ;;
  *"Night"*)
    local new_temp
    new_temp=$(input_menu "Night temperature (K):" "$NIGHT_TEMP")
    if [[ -n "$new_temp" && "$new_temp" =~ ^[0-9]+$ ]]; then
      set_setting "NIGHT_TEMP" "$new_temp"
      notify "Night temperature: ${new_temp}K"
      restart_if_running
    fi
    temperature_menu
    ;;
  *"Presets"*) preset_menu ;;
  *) temperature_menu ;;
  esac
}

# ─── Пресеты ──────────────────────────────────────────────────────────────────
preset_menu() {
  local items=""
  items+="$BACK Back\n"
  items+="Neutral  (6000K / 4000K)\n"
  items+="Default  (5500K / 3500K)\n"
  items+="Warm     (5500K / 3300K)\n"
  items+="Hot      (5500K / 3000K)\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Presets:" "$items")
  case "$ch" in
  *"Exit"* | "") exit 0 ;;
  *"Back"*) temperature_menu ;;
  *"Neutral"*)
    set_setting "DAY_TEMP" "6000"
    set_setting "NIGHT_TEMP" "4000"
    notify "Preset: Neutral"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Default"*)
    set_setting "DAY_TEMP" "5500"
    set_setting "NIGHT_TEMP" "3500"
    notify "Preset: Default"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Warm"*)
    set_setting "DAY_TEMP" "5500"
    set_setting "NIGHT_TEMP" "3300"
    notify "Preset: Warm"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Hot"*)
    set_setting "DAY_TEMP" "5500"
    set_setting "NIGHT_TEMP" "3000"
    notify "Preset: Hot"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *) preset_menu ;;
  esac
}

# ─── Время переходов ──────────────────────────────────────────────────────────
time_menu() {
  source "$CONFIG_FILE"
  local items=""
  items+="$BACK Back\n"
  items+="$TIME Dawn: ${DAWN_TIME}\n"
  items+="$TIME Dusk: ${DUSK_TIME}\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Transition Times:" "$items")
  case "$ch" in
  *"Exit"* | "") exit 0 ;;
  *"Back"*) main_menu ;;
  *"Dawn"*)
    local new_time
    new_time=$(input_menu "Dawn time (HH:MM):" "$DAWN_TIME")
    if [[ -n "$new_time" && "$new_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      set_setting "DAWN_TIME" "\"$new_time\""
      notify "Dawn: $new_time"
      restart_if_running
    fi
    time_menu
    ;;
  *"Dusk"*)
    local new_time
    new_time=$(input_menu "Dusk time (HH:MM):" "$DUSK_TIME")
    if [[ -n "$new_time" && "$new_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      set_setting "DUSK_TIME" "\"$new_time\""
      notify "Dusk: $new_time"
      restart_if_running
    fi
    time_menu
    ;;
  *) time_menu ;;
  esac
}

# ─── Длительность перехода ────────────────────────────────────────────────────
duration_menu() {
  source "$CONFIG_FILE"
  local minutes=$((TRANSITION_DURATION / 60))
  local items=""
  items+="$BACK Back\n"
  items+="$DURATION Current: ${minutes} min\n"
  items+="Short   (15 min)\n"
  items+="Default (30 min)\n"
  items+="Long    (45 min)\n"
  items+="Extra   (60 min)\n"
  items+="Manual\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Transition Duration:" "$items")
  case "$ch" in
  *"Exit"* | "") exit 0 ;;
  *"Back"*) main_menu ;;
  *"Short"*)
    set_setting "TRANSITION_DURATION" "900"
    notify "15 min"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Default"*)
    set_setting "TRANSITION_DURATION" "1800"
    notify "30 min"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Long"*)
    set_setting "TRANSITION_DURATION" "2700"
    notify "45 min"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Extra"*)
    set_setting "TRANSITION_DURATION" "3600"
    notify "60 min"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Manual"*)
    local new_min
    new_min=$(input_menu "Duration (minutes):" "$minutes")
    if [[ -n "$new_min" && "$new_min" =~ ^[0-9]+$ ]]; then
      set_setting "TRANSITION_DURATION" "$((new_min * 60))"
      notify "Transition: ${new_min} min"
      restart_if_running
    fi
    sleep 0.5
    main_menu
    ;;
  *) duration_menu ;;
  esac
}

# ─── Режим работы ─────────────────────────────────────────────────────────────
mode_menu() {
  source "$CONFIG_FILE"
  local lat_val lon_val current_mode="Fixed"
  lat_val=$(grep "^LAT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "' 2>/dev/null || true)
  lon_val=$(grep "^LON=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "' 2>/dev/null || true)
  [[ -n "$lat_val" ]] && current_mode="Auto (${lat_val}, ${lon_val})"

  local items=""
  items+="$BACK Back\n"
  items+="$MODE Current: $current_mode\n"
  items+="Fixed mode\n"
  items+="Auto mode\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Mode:" "$items")
  case "$ch" in
  *"Exit"* | "") exit 0 ;;
  *"Back"*) main_menu ;;
  *"Fixed"*)
    comment_setting "LAT"
    comment_setting "LON"
    notify "Mode: Fixed"
    restart_if_running
    sleep 0.5
    main_menu
    ;;
  *"Auto"*)
    local new_lat new_lon
    new_lat=$(input_menu "Latitude (e.g. 53.9):" "${lat_val:-53.9}")
    if [[ -n "$new_lat" ]]; then
      new_lon=$(input_menu "Longitude (e.g. 27.6):" "${lon_val:-27.6}")
      if [[ -n "$new_lon" ]]; then
        set_setting "LAT" "\"$new_lat\""
        set_setting "LON" "\"$new_lon\""
        notify "Mode: Auto ($new_lat, $new_lon)"
        restart_if_running
      fi
    fi
    sleep 0.5
    main_menu
    ;;
  *) mode_menu ;;
  esac
}

# ─── Точка входа ──────────────────────────────────────────────────────────────
init_config
check_script
main_menu
