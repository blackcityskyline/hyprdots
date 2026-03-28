#!/usr/bin/env bash
# Night Shift Control — backend (wlsunset)
# ~/.config/rofi/nightshift/rofi-nightshift.sh

# Защита от параллельного запуска
LOCKFILE="/tmp/wlsunset.lock"
if [ -f "$LOCKFILE" ]; then
  # Если lock старше 10 секунд — считаем его зависшим и удаляем
  if [ $(( $(date +%s) - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0) )) -lt 10 ]; then
    echo "Another instance is running, skipping" >&2
    exit 0
  fi
fi
touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/nightshift/nightshift.conf"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  DAY_TEMP=5500
  NIGHT_TEMP=3300
  DAWN_TIME="14:00"
  DUSK_TIME="18:00"
  TRANSITION_DURATION=2700
fi

PIDFILE="/tmp/wlsunset.pid"

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

notify() {
  command -v notify-send &>/dev/null &&
    notify-send "Night Shift" "$1" -t 2000 2>/dev/null || true
  echo "$1" >&2
}

is_running() {
  [[ -f "$PIDFILE" ]] || return 1
  local pid
  pid=$(cat "$PIDFILE" 2>/dev/null)
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null &&
    ps -p "$pid" -o comm= 2>/dev/null | grep -q "wlsunset"
}

get_status() { is_running && echo "on" || echo "off"; }

start_wlsunset() {
  [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
  # Убиваем все зависшие wlsunset независимо от PIDFILE
  pkill -9 -x wlsunset 2>/dev/null || true
  rm -f "$PIDFILE"
  sleep 0.5

  command -v wlsunset &>/dev/null || {
    notify "Error: wlsunset not found"
    exit 1
  }

  if [[ $DAY_TEMP -le $NIGHT_TEMP ]]; then
    notify "Error: DAY_TEMP ($DAY_TEMP) must be higher than NIGHT_TEMP ($NIGHT_TEMP)"
    exit 1
  fi

  local -a cmd=(wlsunset)
  if [[ -n "${LAT:-}" && -n "${LON:-}" ]]; then
    cmd+=(-l "$LAT" -L "$LON")
  elif [[ -n "${DAWN_TIME:-}" && -n "${DUSK_TIME:-}" ]]; then
    cmd+=(-S "$DAWN_TIME" -s "$DUSK_TIME")
  fi
  cmd+=(-t "$NIGHT_TEMP" -T "$DAY_TEMP" -d "$TRANSITION_DURATION")

  echo "Starting: ${cmd[*]}" >&2
  "${cmd[@]}" >/tmp/wlsunset.log 2>&1 &
  local pid=$!
  sleep 2

  if kill -0 "$pid" 2>/dev/null; then
    echo "$pid" >"$PIDFILE"
    notify "Night Shift enabled"
  else
    notify "Error: failed to start wlsunset"
    cat /tmp/wlsunset.log >&2
    exit 1
  fi
}

stop_wlsunset() {
  if is_running; then
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
      sleep 0.5
      kill -9 "$pid" 2>/dev/null || true
    fi
    # Убиваем все wlsunset процессы и ждём освобождения gamma control
    pkill -x wlsunset 2>/dev/null || true
    sleep 0.3
    pkill -9 -x wlsunset 2>/dev/null || true
    rm -f "$PIDFILE"
    # Ждём пока compositor освободит gamma control — НЕ запускаем wlsunset для сброса
    # Hyprland сам сбрасывает гамму когда клиент отключается
    sleep 0.5
    notify "Night Shift disabled"
  else
    notify "Night Shift is already off"
  fi
}

toggle() { is_running && stop_wlsunset || start_wlsunset; }

status() {
  if is_running; then
    echo "Night Shift: ON"
    echo "Day: ${DAY_TEMP}K / Night: ${NIGHT_TEMP}K"
    if [[ -n "${LAT:-}" && -n "${LON:-}" ]]; then
      echo "Mode: Auto (lat: $LAT, lon: $LON)"
    else
      echo "Mode: Fixed (dawn: $DAWN_TIME, dusk: $DUSK_TIME)"
    fi
    echo "Transition: ${TRANSITION_DURATION}s"
    [[ -f "$PIDFILE" ]] && echo "PID: $(cat "$PIDFILE")"
  else
    echo "Night Shift: OFF"
  fi
}

case "${1:-toggle}" in
on | start) start_wlsunset ;;
off | stop) stop_wlsunset ;;
toggle) toggle ;;
status) status ;;
restart)
  stop_wlsunset
  sleep 2
  start_wlsunset
  ;;
*)
  echo "Usage: $0 {on|start|off|stop|toggle|status|restart}"
  echo "Current status: $(get_status)"
  exit 1
  ;;
esac
