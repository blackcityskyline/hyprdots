#!/usr/bin/env bash
# Night Shift Manager - только управление wlsunset

# ==================== НАСТРОЙКИ ====================

# Температура (в Кельвинах)
DAY_TEMP=5500
NIGHT_TEMP=3500

# Время (24-часовой формат HH:MM)
DAWN_TIME="14:00" # Время рассвета
DUSK_TIME="18:00" # Время заката

# Длительность перехода (в секундах!)
TRANSITION_DURATION=2700 # 45 минут в секундах

# Координаты (опционально)
# LAT="53.9"
# LON="27.6"

# ==================== КОД ====================

PIDFILE="/tmp/wlsunset.pid"
STATUSFILE="/tmp/wlsunset.status"

# Экспорт переменных окружения для Wayland
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

notify() {
    if command -v notify-send &>/dev/null; then
        notify-send "Night Shift" "$1" -t 2000 -i weather-clear-night 2>/dev/null || true
    fi
    echo "$1" >&2
}

is_running() {
    if [[ -f "$PIDFILE" ]]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            # Проверяем, что это действительно wlsunset
            if ps -p "$pid" -o comm= 2>/dev/null | grep -q "wlsunset"; then
                return 0
            fi
        fi
    fi
    return 1
}

get_status() {
    if is_running; then
        echo "on"
    else
        echo "off"
    fi
}

start_wlsunset() {
    # Останавливаем если уже запущен
    if is_running; then
        stop_wlsunset
        sleep 1
    fi

    # Проверяем наличие wlsunset
    if ! command -v wlsunset &>/dev/null; then
        notify "Ошибка: wlsunset не найден!"
        exit 1
    fi

    # Проверяем логику температур
    if [[ $DAY_TEMP -le $NIGHT_TEMP ]]; then
        notify "Ошибка: DAY_TEMP ($DAY_TEMP) должна быть ВЫШЕ NIGHT_TEMP ($NIGHT_TEMP)"
        exit 1
    fi

    # Формируем команду
    local cmd="wlsunset"

    # Если заданы координаты, используем их
    if [[ -n "${LAT:-}" && -n "${LON:-}" ]]; then
        cmd+=" -l $LAT -L $LON"
        echo "Используем координаты: $LAT, $LON" >&2
    # Иначе используем заданное время
    elif [[ -n "$DAWN_TIME" && -n "$DUSK_TIME" ]]; then
        cmd+=" -S $DAWN_TIME -s $DUSK_TIME"
        echo "Используем фиксированное время: рассвет $DAWN_TIME, закат $DUSK_TIME" >&2
    fi

    # wlsunset ожидает: -t (ночная/нижняя) -T (дневная/верхняя)
    cmd+=" -t $NIGHT_TEMP -T $DAY_TEMP -d $TRANSITION_DURATION"

    # Запускаем в фоне
    echo "Запускаем: $cmd" >&2
    $cmd > /tmp/wlsunset.log 2>&1 &
    local pid=$!

    # Даем процессу время запуститься
    sleep 2

    # Проверяем, запустился ли процесс
    if kill -0 "$pid" 2>/dev/null; then
        echo "$pid" > "$PIDFILE"
        echo "on" > "$STATUSFILE"
        notify "Night Shift включен"
        echo "PID: $pid, статус: запущен" >&2
        
        # Информация о настройках
        if [[ -n "${LAT:-}" && -n "${LON:-}" ]]; then
            echo "Режим: автоматический (по координатам)" >&2
        else
            echo "Day: ${DAY_TEMP}K, Night: ${NIGHT_TEMP}K" >&2
            echo "Переход: $DAWN_TIME → $DUSK_TIME" >&2
        fi
    else
        notify "Ошибка: не удалось запустить wlsunset"
        echo "Логи:" >&2
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
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$PIDFILE"
        echo "off" > "$STATUSFILE"
        
        # Сбрасываем температуру к дневной
        if command -v wlsunset &>/dev/null; then
            timeout 2 wlsunset -t $DAY_TEMP -T $DAY_TEMP -d 1 >/dev/null 2>&1 &
        fi
        
        notify "Night Shift выключен"
        echo "Night Shift остановлен" >&2
    else
        notify "Night Shift уже выключен"
    fi
}

toggle() {
    if is_running; then
        stop_wlsunset
    else
        start_wlsunset
    fi
}

status() {
    local current_status
    current_status=$(get_status)

    if [[ "$current_status" == "on" ]]; then
        echo "Night Shift: ON"
        echo "Day: ${DAY_TEMP}K, Night: ${NIGHT_TEMP}K"
        if [[ -n "${LAT:-}" && -n "${LON:-}" ]]; then
            echo "Режим: Авто (Широта: $LAT, Долгота: $LON)"
        else
            echo "Режим: Ручной (Рассвет: $DAWN_TIME, Закат: $DUSK_TIME)"
        fi
        echo "Переход: ${TRANSITION_DURATION} сек"
        if [[ -f "$PIDFILE" ]]; then
            echo "PID: $(cat "$PIDFILE" 2>/dev/null)"
        fi
    else
        echo "Night Shift: OFF"
    fi
}

# Обработка аргументов
case "${1:-toggle}" in
    on|start)
        start_wlsunset
        ;;
    off|stop)
        stop_wlsunset
        ;;
    toggle)
        toggle
        ;;
    status)
        status
        ;;
    restart)
        stop_wlsunset
        sleep 2
        start_wlsunset
        ;;
    *)
        echo "Использование: $0 {on|start|off|stop|toggle|status|restart}"
        echo "Текущий статус: $(get_status)"
        exit 1
        ;;
esac