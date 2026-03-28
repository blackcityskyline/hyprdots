#!/usr/bin/env bash
# Bluetooth Manager - wofi menu version

set -uo pipefail
export LC_ALL="${LC_ALL:-C.UTF-8}"

# Config
W=250 POS=3 X=-18 Y=15
CACHE="$HOME/.cache/bluetooth-wofi"
CSS_FILE="$HOME/.config/wofi/style.css"
mkdir -p "$CACHE" || {
  echo "ERROR: Cannot create cache directory $CACHE" >&2
  exit 1
}

# Icons
BTON="󰂯" BTOFF="󰂲" CON="✓" PAIRED="󰂱" SCAN="󰒓" TRUST="󰷖"
REMOVE="󰆴" BACK="󰜺" EXIT="󰿅" POW="�" DISC="󰖪"
AUDIO="󰋋" PHONE="󰏲" COMPUTER="󰟀" DEVICE="󰂰"

notify() {
  if command -v notify-send &>/dev/null; then
    notify-send "Bluetooth" "$1" -t "${2:-2000}" 2>/dev/null || true
  fi
  echo "$1" >&2
}

die() {
  echo "ERROR: $1" >&2
  notify "$1" 5000
  exit 1
}

check_deps() {
  local missing=0

  if ! command -v bluetoothctl &>/dev/null; then
    echo "ERROR: bluetoothctl is not installed" >&2
    missing=1
  fi

  if ! command -v wofi &>/dev/null; then
    echo "ERROR: wofi is not installed" >&2
    missing=1
  fi

  [[ $missing -eq 1 ]] && exit 1
  return 0
}

# Bluetooth helpers
bt_power_state() {
  bluetoothctl show 2>/dev/null | grep -q "Powered: yes"
}

bt_power_on() {
  bluetoothctl power on &>/dev/null
  sleep 1
}

bt_power_off() {
  bluetoothctl power off &>/dev/null
}

bt_scanning() {
  bluetoothctl show 2>/dev/null | grep -q "Discovering: yes"
}

# Get device icon based on class/name
get_device_icon() {
  local name="$1"
  case "$name" in
  *[Hh]eadphone* | *[Hh]eadset* | *[Ee]arbud* | *[Ss]peaker* | *[Aa]udio*) echo "$AUDIO" ;;
  *[Pp]hone* | *[Mm]obile*) echo "$PHONE" ;;
  *[Cc]omputer* | *[Ll]aptop* | *PC*) echo "$COMPUTER" ;;
  *) echo "$DEVICE" ;;
  esac
}

# Parse bluetoothctl device list
parse_devices() {
  local type="$1" # "paired" or "scanned"
  local cache="$CACHE/bt-${type}"
  local cache_data="$CACHE/bt-data-${type}"

  # Check cache (5 seconds for scanned, 30 for paired)
  local max_age=5
  [[ "$type" == "paired" ]] && max_age=30

  if [[ -f "$cache" && $(($(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0))) -lt $max_age ]]; then
    cat "$cache"
    return
  fi

  >"$cache"
  >"$cache_data"

  local cnt=1

  if [[ "$type" == "paired" ]]; then
    bluetoothctl devices Paired 2>/dev/null | while IFS= read -r line; do
      local mac name
      mac=$(echo "$line" | awk '{print $2}')
      name=$(echo "$line" | cut -d' ' -f3-)
      [[ -z "$mac" || -z "$name" ]] && continue

      local info icon="$DEVICE" status=" " trusted=""
      info=$(bluetoothctl info "$mac" 2>/dev/null)

      # Get device icon
      icon=$(get_device_icon "$name")

      # Check if connected
      if echo "$info" | grep -q "Connected: yes"; then
        status="$CON"
      fi

      # Check if trusted
      if echo "$info" | grep -q "Trusted: yes"; then
        trusted="$TRUST"
      fi

      # Truncate long names
      local display_name="$name"
      ((${#display_name} > 30)) && display_name="${display_name:0:27}..."

      echo "$icon $display_name $status $trusted" >>"$cache"
      echo "$cnt|$mac|$name" >>"$cache_data"
      ((cnt++))
    done
  else
    # Scanned devices (not paired)
    local paired_macs
    paired_macs=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}')

    bluetoothctl devices 2>/dev/null | while IFS= read -r line; do
      local mac name
      mac=$(echo "$line" | awk '{print $2}')
      name=$(echo "$line" | cut -d' ' -f3-)
      [[ -z "$mac" || -z "$name" ]] && continue

      # Skip if already paired
      echo "$paired_macs" | grep -q "^$mac$" && continue

      local icon
      icon=$(get_device_icon "$name")

      # Get RSSI if available
      local rssi=""
      local info
      info=$(bluetoothctl info "$mac" 2>/dev/null)
      if echo "$info" | grep -q "RSSI:"; then
        rssi=$(echo "$info" | grep "RSSI:" | awk '{print $2}')
        rssi=" [$rssi dBm]"
      fi

      local display_name="$name"
      ((${#display_name} > 30)) && display_name="${display_name:0:27}..."

      echo "$icon $display_name$rssi" >>"$cache"
      echo "$cnt|$mac|$name" >>"$cache_data"
      ((cnt++))
    done
  fi

  [[ -s "$cache" ]] && cat "$cache" || echo "No devices found"
}

# Get device info by line number
get_device_by_line() {
  local type="$1" line_num="$2"
  local cache_data="$CACHE/bt-data-${type}"
  [[ -f "$cache_data" ]] || return 1
  awk -F'|' -v n="$line_num" '$1==n {print $2"|"$3}' "$cache_data"
}

# Scanning
start_scan() {
  notify "Scanning for devices..." 2000
  rm -f "$CACHE/bt-scanned" "$CACHE/bt-data-scanned"

  # Start scan in background
  (
    echo "scan on" | bluetoothctl &>/dev/null &
    local pid=$!
    sleep 8
    kill $pid 2>/dev/null || true
    echo "scan off" | bluetoothctl &>/dev/null
  ) &

  sleep 3
}

stop_scan() {
  echo "scan off" | bluetoothctl &>/dev/null
}

# Device operations
pair_device() {
  local mac="$1" name="$2"
  notify "Pairing with $name..." 2000

  local result
  if result=$(timeout 30 bluetoothctl pair "$mac" 2>&1); then
    if echo "$result" | grep -qi "successful\|paired"; then
      notify "Paired with $name" 2000
      # Auto-trust after pairing
      bluetoothctl trust "$mac" &>/dev/null
      return 0
    fi
  fi

  notify "Failed to pair with $name" 3000
  return 1
}

connect_device() {
  local mac="$1" name="$2"
  notify "Connecting to $name..." 2000

  local result
  if result=$(timeout 30 bluetoothctl connect "$mac" 2>&1); then
    if echo "$result" | grep -qi "successful\|connected"; then
      notify "Connected to $name" 2000
      return 0
    fi
  fi

  notify "Failed to connect to $name" 3000
  return 1
}

disconnect_device() {
  local mac="$1" name="$2"
  notify "Disconnecting from $name..." 2000

  if bluetoothctl disconnect "$mac" &>/dev/null; then
    notify "Disconnected from $name" 2000
    return 0
  else
    notify "Failed to disconnect from $name" 3000
    return 1
  fi
}

trust_device() {
  local mac="$1" name="$2"

  if bluetoothctl trust "$mac" &>/dev/null; then
    notify "$name is now trusted" 2000
    return 0
  else
    notify "Failed to trust $name" 2000
    return 1
  fi
}

untrust_device() {
  local mac="$1" name="$2"

  if bluetoothctl untrust "$mac" &>/dev/null; then
    notify "$name is no longer trusted" 2000
    return 0
  else
    notify "Failed to untrust $name" 2000
    return 1
  fi
}

remove_device() {
  local mac="$1" name="$2"

  if bluetoothctl remove "$mac" &>/dev/null; then
    notify "Removed $name" 2000
    return 0
  else
    notify "Failed to remove $name" 2000
    return 1
  fi
}

disconnect_all() {
  notify "Disconnecting all devices..." 2000
  local count=0
  local devices

  devices=$(bluetoothctl devices Paired 2>/dev/null)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local mac name
    mac=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | cut -d' ' -f3-)
    [[ -z "$mac" ]] && continue

    local info
    info=$(bluetoothctl info "$mac" 2>/dev/null)

    if echo "$info" | grep -q "Connected: yes"; then
      if bluetoothctl disconnect "$mac" &>/dev/null; then
        ((count++))
      fi
    fi
  done <<<"$devices"

  if [[ $count -gt 0 ]]; then
    notify "Disconnected $count device(s)" 2000
  else
    notify "No connected devices" 2000
  fi
}

# Menu helpers
menu() {
  local result

  # Count actual lines in content
  local line_count
  line_count=$(echo -e "$2" | wc -l)

  # Use max of provided lines or auto-calculated, with a reasonable maximum
  local max_lines="${3:-20}"
  local display_lines=$((line_count + 1)) # +1 for bottom padding
  [[ $display_lines -gt $max_lines ]] && display_lines=$max_lines

  local wofi_cmd="wofi --dmenu -p \"$1\" --width \"$W\" --location \"$POS\" --xoffset \"$X\" --yoffset \"$Y\" --lines \"$display_lines\""

  # Add CSS if file exists
  [[ -f "$CSS_FILE" ]] && wofi_cmd+=" --style \"$CSS_FILE\""

  result=$(echo -e "$2" | eval "$wofi_cmd" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 1 ]]; then
    echo ""
    return 0
  elif [[ $exit_code -ne 0 ]]; then
    echo "ERROR: wofi failed with code $exit_code: $result" >&2
    echo ""
    return 1
  fi

  echo "$result"
  return 0
}

# Main menu
main_menu() {
  if ! bt_power_state; then
    local ch
    ch=$(menu "Bluetooth is disabled" "$POW Turn Bluetooth on\n$EXIT Exit")
    if [[ "$ch" == *"Turn Bluetooth on"* ]]; then
      bt_power_on
      exec "$0"
    fi
    return 0
  fi

  local items=""
  items+="$BTON Bluetooth is ON\n"
  items+="$SCAN Scan for devices\n"
  items+="$PAIRED Paired devices\n"
  items+="$DISC Disconnect all\n"
  items+="$POW Turn off Bluetooth\n"
  items+="$EXIT Exit"

  local ch
  ch=$(menu "Bluetooth Manager" "$items")
  handle_main_choice "$ch"
}

handle_main_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    exit 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Turn off"* ]]; then
    bt_power_off
    notify "Bluetooth off" 2000
    exit 0
  elif [[ "$ch" == *"Disconnect all"* ]]; then
    disconnect_all
    sleep 1
    exec "$0"
  elif [[ "$ch" == *"Scan for devices"* ]]; then
    scan_menu
    return 0
  elif [[ "$ch" == *"Paired devices"* ]]; then
    paired_menu
    return 0
  fi

  exec "$0"
}

# Scan menu
scan_menu() {
  start_scan

  local devices
  devices=$(parse_devices "scanned")

  local items=""
  items+="$BACK Back"
  items+=$'\n'"$SCAN Rescan"
  items+=$'\n'"$EXIT Exit"

  # Add devices
  local cnt=1
  while IFS= read -r line; do
    [[ "$line" == "No devices found" ]] && continue
    items+=$'\n'"$cnt. $line"
    ((cnt++))
  done <<<"$devices"

  local ch
  ch=$(menu "New devices:" "$items")
  handle_scan_choice "$ch"
}

handle_scan_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    stop_scan
    exit 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    stop_scan
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    stop_scan
    exec "$0"
  elif [[ "$ch" == *"Rescan"* ]]; then
    rm -f "$CACHE/bt-scanned" "$CACHE/bt-data-scanned"
    scan_menu
    return 0
  fi

  if [[ "$ch" =~ ^([0-9]+)\. ]]; then
    local num="${BASH_REMATCH[1]}"
    local device_info mac name

    device_info=$(get_device_by_line "scanned" "$num")
    mac="${device_info%%|*}"
    name="${device_info#*|}"

    if [[ -z "$mac" ]]; then
      notify "Failed to get device info" 2000
      exec "$0"
    fi

    stop_scan

    # Try to pair
    if pair_device "$mac" "$name"; then
      sleep 1
      # After pairing, try to connect
      connect_device "$mac" "$name"
    fi

    sleep 1
    exec "$0"
  fi

  stop_scan
  exec "$0"
}

# Paired devices menu
paired_menu() {
  local devices
  devices=$(parse_devices "paired")

  local items=""
  items+="$BACK Back"
  items+=$'\n'"$SCAN Refresh"
  items+=$'\n'"$EXIT Exit"

  # Add devices
  local cnt=1
  while IFS= read -r line; do
    [[ "$line" == "No devices found" ]] && continue
    items+=$'\n'"$cnt. $line"
    ((cnt++))
  done <<<"$devices"

  local ch
  ch=$(menu "Paired devices:" "$items")
  handle_paired_choice "$ch"
}

handle_paired_choice() {
  local ch="$1"

  if [[ -z "$ch" ]]; then
    exit 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    exec "$0"
  elif [[ "$ch" == *"Refresh"* ]]; then
    rm -f "$CACHE/bt-paired" "$CACHE/bt-data-paired"
    paired_menu
    return 0
  fi

  if [[ "$ch" =~ ^([0-9]+)\. ]]; then
    local num="${BASH_REMATCH[1]}"
    local device_info mac name

    device_info=$(get_device_by_line "paired" "$num")
    mac="${device_info%%|*}"
    name="${device_info#*|}"

    if [[ -z "$mac" ]]; then
      notify "Failed to get device info" 2000
      exec "$0"
    fi

    device_actions_menu "$mac" "$name"
    return 0
  fi

  exec "$0"
}

# Device actions menu
device_actions_menu() {
  local mac="$1" name="$2"

  # Get device info
  local info
  info=$(bluetoothctl info "$mac" 2>/dev/null)

  local is_connected=false is_trusted=false
  echo "$info" | grep -q "Connected: yes" && is_connected=true
  echo "$info" | grep -q "Trusted: yes" && is_trusted=true

  local items=""
  items+="$BACK Back"
  items+=$'\n'

  if $is_connected; then
    items+="$DISC Disconnect"
  else
    items+="$CON Connect"
  fi

  items+=$'\n'

  if $is_trusted; then
    items+="$TRUST Untrust device"
  else
    items+="$TRUST Trust device"
  fi

  items+=$'\n'"$REMOVE Remove device"
  items+=$'\n'"$EXIT Exit"

  local ch
  ch=$(menu "Device: $name" "$items")
  handle_device_action "$ch" "$mac" "$name" "$is_connected" "$is_trusted"
}

handle_device_action() {
  local ch="$1" mac="$2" name="$3" is_connected="$4" is_trusted="$5"

  if [[ -z "$ch" ]]; then
    exec "$0"
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    paired_menu
    return 0
  elif [[ "$ch" == *"Connect"* ]]; then
    connect_device "$mac" "$name"
    sleep 1
    exec "$0"
  elif [[ "$ch" == *"Disconnect"* ]]; then
    disconnect_device "$mac" "$name"
    sleep 1
    exec "$0"
  elif [[ "$ch" == *"Trust"* ]]; then
    if [[ "$is_trusted" == "true" ]]; then
      untrust_device "$mac" "$name"
    else
      trust_device "$mac" "$name"
    fi
    sleep 1
    device_actions_menu "$mac" "$name"
    return 0
  elif [[ "$ch" == *"Remove"* ]]; then
    remove_device "$mac" "$name"
    sleep 1
    exec "$0"
  fi

  exec "$0"
}

# Cleanup
cleanup() {
  find "$CACHE" -name "bt-*" -mmin +10 -delete 2>/dev/null || true
  stop_scan 2>/dev/null || true
}
trap cleanup EXIT

main() {
  check_deps
  cleanup
  main_menu
}

main "$@"
