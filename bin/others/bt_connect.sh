#!/usr/bin/env bash
# set -x  # For debug

# ===== Settings =====
# Remove comment for manual settings
# MANUAL_MACS=(
#     "AA:BB:CC:DD:EE:FF"
#     "11:22:33:44:55:66"
# )
CONNECT_TIMEOUT=20 # Waiting for device
# =====================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

enable_bluetooth() {
  if command -v rfkill &>/dev/null; then
    rfkill unblock bluetooth 2>/dev/null || true
  fi
  if ! bluetoothctl show | grep -q "Powered: yes"; then
    log_info "Включаем Bluetooth..."
    bluetoothctl power on || {
      log_error "Не удалось включить Bluetooth"
      return 1
    }
    sleep 2
  else
    log_info "Bluetooth уже включён."
  fi
}

get_target_macs() {
  local macs=()
  if [[ -n "${MANUAL_MACS:-}" && ${#MANUAL_MACS[@]} -gt 0 ]]; then
    for mac in "${MANUAL_MACS[@]}"; do
      macs+=("${mac^^}")
    done
  else
    while read -r _ mac _; do
      macs+=("${mac^^}")
    done < <(bluetoothctl devices Paired)
  fi
  printf '%s\n' "${macs[@]}"
}

_claim_winner() {
  local mac="$1" result_file="$2"
  local tmp
  tmp=$(mktemp)
  echo "$mac" >"$tmp"
  if ln "$tmp" "$result_file" 2>/dev/null; then
    log_info "[$mac] 🏆 Выбран как победитель."
    rm -f "$tmp"
    return 0
  fi
  log_warn "[$mac] Подключился, но победитель уже выбран. Отключаюсь."
  bluetoothctl disconnect "$mac" >/dev/null 2>&1
  rm -f "$tmp"
  return 1
}

try_connect() {
  local mac="$1"
  local result_file="$2"

  # УСКОРЕНИЕ 1: если устройство уже подключено — сразу победитель
  if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
    log_info "[$mac] ✅ Уже подключено!"
    _claim_winner "$mac" "$result_file"
    return 0
  fi

  log_info "[$mac] Пробую подключиться..."

  # УСКОРЕНИЕ 2: пишем вывод bluetoothctl в tmp-файл и читаем его параллельно.
  # Как только видим строку успеха — сразу реагируем, не ждём завершения процесса.
  local tmp_out
  tmp_out=$(mktemp)
  timeout "$CONNECT_TIMEOUT" bluetoothctl connect "$mac" >"$tmp_out" 2>&1 &
  local bt_pid=$!

  local success=false
  while kill -0 "$bt_pid" 2>/dev/null; do
    if grep -qiE "Connection successful|Connected: yes" "$tmp_out" 2>/dev/null; then
      success=true
      break
    fi
    sleep 0.2
  done

  # Если вышли по завершению процесса — делаем финальную проверку файла
  if ! $success; then
    grep -qiE "Connection successful|Connected: yes" "$tmp_out" 2>/dev/null && success=true
  fi

  # Убиваем bluetoothctl (BlueZ-демон уже знает о соединении — kill безопасен)
  kill "$bt_pid" 2>/dev/null
  wait "$bt_pid" 2>/dev/null
  rm -f "$tmp_out"

  if $success; then
    log_info "[$mac] ✅ Подключено!"
    _claim_winner "$mac" "$result_file"
    return 0
  fi

  # Последняя проверка через info — на случай нестандартного вывода
  if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
    log_info "[$mac] ✅ Подключено (подтверждено через info)!"
    _claim_winner "$mac" "$result_file"
    return 0
  fi

  log_warn "[$mac] ❌ Не удалось подключиться."
  return 1
}

connect_best() {
  local targets=("$@")
  local result_file="/tmp/bt_winner_$$.mac"
  local pids=()

  log_info "Параллельное подключение к ${#targets[@]} устройствам..."
  log_info "Победит первое, которое ответит (= ближайшее доступное)."

  for mac in "${targets[@]}"; do
    try_connect "$mac" "$result_file" &
    pids+=($!)
  done

  # Ждём первого успеха или завершения всех попыток
  local deadline=$(($(date +%s) + CONNECT_TIMEOUT + 5))
  while true; do
    [[ -f "$result_file" ]] && break

    local any_alive=0
    for pid in "${pids[@]}"; do
      kill -0 "$pid" 2>/dev/null && {
        any_alive=1
        break
      }
    done
    [[ $any_alive -eq 0 ]] && break
    [[ $(date +%s) -ge $deadline ]] && break

    sleep 0.5
  done

  # Завершаем оставшиеся фоновые процессы
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null
  done
  wait "${pids[@]}" 2>/dev/null

  if [[ -f "$result_file" ]]; then
    local winner
    winner=$(cat "$result_file")
    rm -f "$result_file"
    log_info "Подключено к: $winner"
    echo "$winner"
    return 0
  fi

  rm -f "$result_file"

  # Последний шанс: может кто-то подключился уже после timeout скрипта
  # (как раз тот случай что наблюдался) — проверяем все устройства
  log_warn "Прямое подключение не зафиксировано. Проверяю статус устройств..."
  for mac in "${targets[@]}"; do
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      log_info "[$mac] Обнаружено активное соединение!"
      echo "$mac"
      return 0
    fi
  done

  log_error "Ни одно устройство не подключилось."
  return 1
}

main() {
  log_info "Запуск скрипта подключения к ближайшему доступному устройству"

  enable_bluetooth || exit 1

  mapfile -t target_macs < <(get_target_macs)
  if [[ ${#target_macs[@]} -eq 0 ]]; then
    log_warn "Нет целевых устройств. Выход."
    exit 0
  fi
  log_info "Целевые MAC (${#target_macs[@]}): ${target_macs[*]}"

  local winner
  if winner=$(connect_best "${target_macs[@]}"); then
    log_info "✅ Готово. Активное устройство: $winner"
    exit 0
  else
    exit 1
  fi
}

main
