#!/usr/bin/env bash
# Night Shift Settings - Interactive wofi menu

set -uo pipefail
export LC_ALL="${LC_ALL:-C.UTF-8}"

# Config
W=250 POS=3 X=-18 Y=15
SCRIPT_PATH="$HOME/bin/nightshift.sh"
CSS_FILE="$HOME/.config/wofi/style.css"

# Icons
SETTINGS="󰒓" TEMP="󰔏" TIME="󰥔" DURATION="󰔛" MODE="󰖔"
STATUS="󰋼" TOGGLE="󰔡" BACK="󰜺" EXIT="󰿅" SAVE="󰆓"

notify() {
  if command -v notify-send &>/dev/null; then
    notify-send "Night Shift" "$1" -t "${2:-2000}" 2>/dev/null || true
  fi
  echo "$1" >&2
}

# Проверка существования скрипта
check_script() {
  if [[ ! -f "$SCRIPT_PATH" ]]; then
    notify "Error: script not found at $SCRIPT_PATH" 5000
    exit 1
  fi
}

# Получение настроек из скрипта
get_setting() {
  local key="$1"
  grep "^${key}=" "$SCRIPT_PATH" | cut -d'=' -f2 | tr -d ' "' | sed 's/#.*//'
}

# Установка настроек в скрипт
set_setting() {
  local key="$1" value="$2"
  sed -i "s/^${key}=.*/${key}=${value}/" "$SCRIPT_PATH"
}

# Menu helper
menu() {
  local result

  # Count actual lines in content
  local line_count
  line_count=$(echo -e "$2" | wc -l)

  local max_lines="${3:-20}"
  local display_lines=$((line_count + 1))
  [[ $display_lines -gt $max_lines ]] && display_lines=$max_lines

  local wofi_cmd="wofi --dmenu -p \"$1\" --width \"$W\" --location \"$POS\" --xoffset \"$X\" --yoffset \"$Y\" --lines \"$display_lines\""

  [[ -f "$CSS_FILE" ]] && wofi_cmd+=" --style \"$CSS_FILE\""

  result=$(echo -e "$2" | eval "$wofi_cmd" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 1 ]]; then
    echo ""
    return 0
  elif [[ $exit_code -ne 0 ]]; then
    echo "ERROR: wofi failed" >&2
    echo ""
    return 1
  fi

  echo "$result"
  return 0
}

# Input menu для ввода значений
input_menu() {
  local prompt="$1" default="$2"
  local result
  result=$(echo "$default" | wofi --dmenu -p "$prompt" --width "$W" --location "$POS" --xoffset "$X" --yoffset "$Y" 2>&1)
  echo "$result"
}

# Функция для перезапуска скрипта если он запущен
restart_if_running() {
  if bash "$SCRIPT_PATH" status 2>/dev/null | grep -q -i "ON\|включен\|запущен" || pgrep -f "wlsunset" >/dev/null; then
    bash "$SCRIPT_PATH" restart
    return 0
  fi
  return 1
}

# Главное меню
main_menu() {
  local day_temp night_temp dawn_time dusk_time duration
  day_temp=$(get_setting "DAY_TEMP")
  night_temp=$(get_setting "NIGHT_TEMP")
  dawn_time=$(get_setting "DAWN_TIME")
  dusk_time=$(get_setting "DUSK_TIME")
  duration=$(get_setting "TRANSITION_DURATION")

  # Определяем статус - корректная проверка
  local status_text="OFF"
  if bash "$SCRIPT_PATH" status 2>/dev/null | grep -q -i "ON\|включен\|запущен\|работает\|running" || pgrep -f "wlsunset" >/dev/null; then
    status_text="ON"
  fi

  local items=""
  items+="$STATUS Status: $status_text\n"
  items+="$TOGGLE On/Off Night Shift\n"
  items+="$TEMP Temp: ${day_temp}K / ${night_temp}K\n"
  items+="$TIME Time: ${dawn_time} - ${dusk_time}\n"
  items+="$DURATION Transition: $((duration / 60)) min\n"
  items+="$MODE Mode (auto/fixed)\n"
  items+="$SETTINGS Show settings\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Night Shift Settings" "$items")
  handle_main_choice "$ch"
}

handle_main_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    exit 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"On/Off"* ]]; then
    bash "$SCRIPT_PATH" toggle
    sleep 1
    main_menu
    return 0
  elif [[ "$ch" == *"Temp:"* ]]; then
    temperature_menu
    return 0
  elif [[ "$ch" == *"Time:"* ]]; then
    time_menu
    return 0
  elif [[ "$ch" == *"Transition:"* ]]; then
    duration_menu
    return 0
  elif [[ "$ch" == *"Mode"* ]]; then
    mode_menu
    return 0
  elif [[ "$ch" == *"settings"* ]]; then
    show_settings
    return 0
  fi

  main_menu
}

# Меню температур
temperature_menu() {
  local day_temp night_temp
  day_temp=$(get_setting "DAY_TEMP")
  night_temp=$(get_setting "NIGHT_TEMP")

  local items=""
  items+="$BACK Back\n"
  items+="$TEMP Day: ${day_temp}K\n"
  items+="$TEMP Night: ${night_temp}K\n"
  items+="$SETTINGS Presets\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Temperature" "$items")
  handle_temp_choice "$ch"
}

handle_temp_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    main_menu
    return 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    main_menu
    return 0
  elif [[ "$ch" == *"Day"* ]]; then
    local current
    current=$(get_setting "DAY_TEMP")
    local new_temp
    new_temp=$(input_menu "Day temperature (K):" "$current")
    if [[ -n "$new_temp" && "$new_temp" =~ ^[0-9]+$ ]]; then
      set_setting "DAY_TEMP" "$new_temp"
      notify "Day temperature: ${new_temp}K"
      restart_if_running
    fi
    temperature_menu
    return 0
  elif [[ "$ch" == *"Night"* ]]; then
    local current
    current=$(get_setting "NIGHT_TEMP")
    local new_temp
    new_temp=$(input_menu "Night temperature (K):" "$current")
    if [[ -n "$new_temp" && "$new_temp" =~ ^[0-9]+$ ]]; then
      set_setting "NIGHT_TEMP" "$new_temp"
      notify "Night temperature: ${new_temp}K"
      restart_if_running
    fi
    temperature_menu
    return 0
  elif [[ "$ch" == *"Presets"* ]]; then
    preset_menu
    return 0
  fi

  main_menu
}

# Presets температур
preset_menu() {
  local items=""
  items+="$BACK Back\n"
  items+="Neutral (6000K / 4000K)\n"
  items+="Default (5500K / 3500K)\n"
  items+="Warm (5500K / 3300K)\n"
  items+="Very warm (5500K / 3000K)\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Temperature Presets" "$items")

  if [[ -z "$ch" || "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    temperature_menu
    return 0
  elif [[ "$ch" == *"Neutral"* ]]; then
    set_setting "DAY_TEMP" "6000"
    set_setting "NIGHT_TEMP" "4000"
    notify "Preset: Neutral"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Default"* ]]; then
    set_setting "DAY_TEMP" "5500"
    set_setting "NIGHT_TEMP" "3500"
    notify "Preset: Default"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Warm"* ]]; then
    set_setting "DAY_TEMP" "5500"
    set_setting "NIGHT_TEMP" "3300"
    notify "Preset: Warm"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Very warm"* ]]; then
    set_setting "DAY_TEMP" "5500"
    set_setting "NIGHT_TEMP" "3000"
    notify "Preset: Very warm"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  fi

  main_menu
}

# Меню времени перехода
time_menu() {
  local dawn_time dusk_time
  dawn_time=$(get_setting "DAWN_TIME")
  dusk_time=$(get_setting "DUSK_TIME")

  local items=""
  items+="$BACK Back\n"
  items+="$TIME Dawn: ${dawn_time}\n"
  items+="$TIME Dusk: ${dusk_time}\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Transition Times" "$items")
  handle_time_choice "$ch"
}

handle_time_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    main_menu
    return 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    main_menu
    return 0
  elif [[ "$ch" == *"Dawn"* ]]; then
    local current
    current=$(get_setting "DAWN_TIME")
    local new_time
    new_time=$(input_menu "Dawn time (HH:MM):" "$current")
    if [[ -n "$new_time" && "$new_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      set_setting "DAWN_TIME" "\"$new_time\""
      notify "Dawn: $new_time"
      restart_if_running
    fi
    time_menu
    return 0
  elif [[ "$ch" == *"Dusk"* ]]; then
    local current
    current=$(get_setting "DUSK_TIME")
    local new_time
    new_time=$(input_menu "Dusk time (HH:MM):" "$current")
    if [[ -n "$new_time" && "$new_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      set_setting "DUSK_TIME" "\"$new_time\""
      notify "Dusk: $new_time"
      restart_if_running
    fi
    time_menu
    return 0
  fi

  main_menu
}

# Меню длительности перехода
duration_menu() {
  local duration
  duration=$(get_setting "TRANSITION_DURATION")
  local minutes=$((duration / 60))

  local items=""
  items+="$BACK Back\n"
  items+="$DURATION Current: $minutes min\n"
  items+="Short (15 min)\n"
  items+="Default (30 min)\n"
  items+="Long (45 min)\n"
  items+="Very long (60 min)\n"
  items+="Manual\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Transition Duration" "$items")
  handle_duration_choice "$ch"
}

handle_duration_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    main_menu
    return 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    main_menu
    return 0
  elif [[ "$ch" == *"Short"* ]]; then
    set_setting "TRANSITION_DURATION" "900"
    notify "Transition: 15 min"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Default"* ]]; then
    set_setting "TRANSITION_DURATION" "1800"
    notify "Transition: 30 min"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Long"* ]]; then
    set_setting "TRANSITION_DURATION" "2700"
    notify "Transition: 45 min"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Very long"* ]]; then
    set_setting "TRANSITION_DURATION" "3600"
    notify "Transition: 60 min"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Manual"* ]]; then
    local current
    current=$(get_setting "TRANSITION_DURATION")
    local minutes=$((current / 60))
    local new_minutes
    new_minutes=$(input_menu "Duration (minutes):" "$minutes")
    if [[ -n "$new_minutes" && "$new_minutes" =~ ^[0-9]+$ ]]; then
      local seconds=$((new_minutes * 60))
      set_setting "TRANSITION_DURATION" "$seconds"
      notify "Transition: ${new_minutes} min"
      restart_if_running
    fi
    sleep 0.5
    main_menu
    return 0
  fi

  main_menu
}

# Меню режима (авто/фиксированный)
mode_menu() {
  local lat lon
  lat=$(grep "^LAT=" "$SCRIPT_PATH" | cut -d'=' -f2 | tr -d ' "' | sed 's/#.*//')
  lon=$(grep "^LON=" "$SCRIPT_PATH" | cut -d'=' -f2 | tr -d ' "' | sed 's/#.*//')

  local current_mode="Fixed"
  if [[ -n "$lat" && "$lat" != *"#"* ]]; then
    current_mode="Auto (${lat}, ${lon})"
  fi

  local items=""
  items+="$BACK Back\n"
  items+="$MODE Current: $current_mode\n"
  items+="Fixed mode\n"
  items+="Auto mode (set coordinates)\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Mode" "$items")
  handle_mode_choice "$ch"
}

handle_mode_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    main_menu
    return 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    main_menu
    return 0
  elif [[ "$ch" == *"Fixed"* ]]; then
    # Комментируем LAT и LON
    sed -i 's/^LAT=/# LAT=/' "$SCRIPT_PATH"
    sed -i 's/^LON=/# LON=/' "$SCRIPT_PATH"
    notify "Mode: Fixed"
    restart_if_running
    sleep 0.5
    main_menu
    return 0
  elif [[ "$ch" == *"Auto"* ]]; then
    local new_lat new_lon
    new_lat=$(input_menu "Latitude (e.g., 53.9):" "53.9")
    if [[ -n "$new_lat" ]]; then
      new_lon=$(input_menu "Longitude (e.g., 27.6):" "27.6")
      if [[ -n "$new_lon" ]]; then
        # Раскомментируем и обновляем координаты
        sed -i "s/^# LAT=.*/LAT=\"$new_lat\"/" "$SCRIPT_PATH"
        sed -i "s/^# LON=.*/LON=\"$new_lon\"/" "$SCRIPT_PATH"
        sed -i "s/^LAT=.*/LAT=\"$new_lat\"/" "$SCRIPT_PATH"
        sed -i "s/^LON=.*/LON=\"$new_lon\"/" "$SCRIPT_PATH"
        notify "Mode: Auto ($new_lat, $new_lon)"
        restart_if_running
      fi
    fi
    sleep 0.5
    main_menu
    return 0
  fi

  main_menu
}

# Показать все настройки
show_settings() {
  local settings
  settings=$(bash "$SCRIPT_PATH" status 2>/dev/null)

  notify "Current settings" 4000

  local items=""
  items+="$BACK Back\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Night Shift Status" "$items")

  if [[ "$ch" == *"Back"* ]]; then
    main_menu
    return 0
  fi

  exit 0
}

# Main
main() {
  check_script
  main_menu
}

main "$@"