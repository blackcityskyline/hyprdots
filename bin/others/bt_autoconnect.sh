#!/usr/bin/env bash

# The MAC of the last device is stored in ~/.cache/bluetooth-last-device.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CACHE_FILE="$HOME/.cache/bluetooth-last-device"

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

enable_bluetooth() {
  if command -v rfkill &>/dev/null; then
    rfkill unblock bluetooth
  fi

  if ! bluetoothctl show | grep -q "Powered: yes"; then
    log_info "Bluetooth is off. Turning it on..."
    bluetoothctl power on
    sleep 2
  else
    log_info "Bluetooth is already on."
  fi
}

connect_device() {
  local mac="$1"
  log_info "Attempting to connect to $mac..."

  # Re‑trust the device (for connection errors)
  bluetoothctl untrust "$mac" 2>/dev/null || true
  bluetoothctl trust "$mac" 2>/dev/null || true

  output=$(timeout 15 bluetoothctl connect "$mac" 2>&1)

  if echo "$output" | grep -q "Connection successful"; then
    log_info "Successfully connected to $mac"
    return 0
  else
    log_warn "Failed to connect to $mac"
    return 1
  fi
}

get_last_device() {
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
  fi
}

is_device_paired() {
  local mac="$1"
  bluetoothctl devices Paired | awk '{print $2}' | grep -q "^$mac$"
}

main() {
  log_info "Starting auto‑connect script for the last Bluetooth device..."

  enable_bluetooth
  sleep 3 # time to initialise

  last_mac=$(get_last_device)
  if [ -z "$last_mac" ]; then
    log_warn "Last device cache is empty. Doing nothing."
    exit 0
  fi

  if ! is_device_paired "$last_mac"; then
    log_warn "Device $last_mac not found in paired devices list. Removing cache."
    rm -f "$CACHE_FILE"
    exit 0
  fi

  if connect_device "$last_mac"; then
    log_info "Connection to the last device succeeded."
    exit 0
  else
    log_error "Could not connect to the last device $last_mac."
    exit 1
  fi
}

main
