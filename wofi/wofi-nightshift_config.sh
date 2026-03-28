#!/usr/bin/env bash
# Night Shift Settings - Interactive wofi menu
# ~/.config/wofi/wofi-nightshift_config.sh

set -uo pipefail
export LC_ALL="${LC_ALL:-C.UTF-8}"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/nightshift.conf"
SCRIPT_PATH="$HOME/.config/wofi/wofi-nightshift.sh"
CSS_FILE="$HOME/.config/wofi/style.css"

W=250 POS=3 X=-18 Y=15

# Icons
SETTINGS="󰒓" TEMP="󰔏" TIME="󰥔" DURATION="󰔛" MODE="󰖔"
STATUS="󰋼" TOGGLE="󰔡" BACK="󰜺" EXIT="󰿅"

# ── Конфиг: чтение и запись ────────────────────────────────────────────────────

# Создаём конфиг с дефолтами если не существует
init_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
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
  fi
}

get_setting() {
  local key="$1"
  grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "' | sed 's/#.*//' | tr -d "'"
}

set_setting() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    # Раскомментируем если закомментировано
    sed -i "s|^# ${key}=.*|${key}=${value}|" "$CONFIG_FILE"
    # Если всё ещё нет — добавляем
    grep -q "^${key}=" "$CONFIG_FILE" || echo "${key}=${value}" >>"$CONFIG_FILE"
  fi
}

comment_setting() {
  local key="$1"
  sed -i "s|^${key}=|# ${key}=|" "$CONFIG_FILE"
}

# ── Wofi helpers ───────────────────────────────────────────────────────────────

notify() {
  if command -v notify-send &>/dev/null; then
    notify-send "Night Shift" "$1" -t "${2:-2000}" 2>/dev/null || true
  fi
  echo "$1" >&2
}

menu() {
  local prompt="$1" content="$2"
  local line_count display_lines
  line_count=$(echo -e "$content" | wc -l)
  display_lines=$((line_count + 1))
  [[ $display_lines -gt 20 ]] && display_lines=20

  local wofi_cmd="wofi --dmenu -p \"$prompt\" --width \"$W\" --location \"$POS\" --xoffset \"$X\" --yoffset \"$Y\" --lines \"$display_lines\""
  [[ -f "$CSS_FILE" ]] && wofi_cmd+=" --style \"$CSS_FILE\""

  local result exit_code
  result=$(echo -e "$content" | eval "$wofi_cmd" 2>&1) && exit_code=$? || exit_code=$?

  [[ $exit_code -eq 1 ]] && {
    echo ""
    return 0
  }
  echo "$result"
}

input_menu() {
  local prompt="$1" default="$2"
  echo "$default" | wofi --dmenu -p "$prompt" --width "$W" --location "$POS" --xoffset "$X" --yoffset "$Y" 2>/dev/null
}

check_script() {
  if [[ ! -f "$SCRIPT_PATH" ]]; then
    notify "Error: backend not found at $SCRIPT_PATH" 5000
    exit 1
  fi
}

restart_if_running() {
  if pgrep -f "wlsunset" >/dev/null; then
    bash "$SCRIPT_PATH" restart
  fi
}

# ── Меню ──────────────────────────────────────────────────────────────────────

main_menu() {
  source "$CONFIG_FILE" # перечитываем актуальные значения

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
  ch=$(menu "Night Shift" "$items")

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

temperature_menu() {
  source "$CONFIG_FILE"

  local items=""
  items+="$BACK Back\n"
  items+="$TEMP Day: ${DAY_TEMP}K\n"
  items+="$TEMP Night: ${NIGHT_TEMP}K\n"
  items+="$SETTINGS Presets\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Temperature" "$items")

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

preset_menu() {
  local items=""
  items+="$BACK Back\n"
  items+="Neutral  (6000K / 4000K)\n"
  items+="Default  (5500K / 3500K)\n"
  items+="Warm     (5500K / 3300K)\n"
  items+="Hot      (5500K / 3000K)\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Temperature Presets" "$items")

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

time_menu() {
  source "$CONFIG_FILE"

  local items=""
  items+="$BACK Back\n"
  items+="$TIME Dawn: ${DAWN_TIME}\n"
  items+="$TIME Dusk: ${DUSK_TIME}\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Transition Times" "$items")

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
  ch=$(menu "Transition Duration" "$items")

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

mode_menu() {
  source "$CONFIG_FILE"

  local current_mode="Fixed"
  local lat_val lon_val
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
  ch=$(menu "Mode" "$items")

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
    new_lat=$(input_menu "Latitude (e.g., 53.9):" "${lat_val:-53.9}")
    if [[ -n "$new_lat" ]]; then
      new_lon=$(input_menu "Longitude (e.g., 27.6):" "${lon_val:-27.6}")
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

# ── Main ──────────────────────────────────────────────────────────────────────
init_config
check_script
main_menu
