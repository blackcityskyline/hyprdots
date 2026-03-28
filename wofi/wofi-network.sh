#!/usr/bin/env bash
# WiFi Manager - Fixed menu order version

set -uo pipefail
export LC_ALL="${LC_ALL:-C.UTF-8}"

# Config
W=250 POS=3 X=-18 Y=15
CACHE="$HOME/.cache/wifi-wofi"
CSS_FILE="$HOME/.config/wofi/style.css"
mkdir -p "$CACHE" || {
  echo "ERROR: Cannot create cache directory $CACHE" >&2
  exit 1
}

# Icons
WON="󰖩" WOFF="󰖪" CON="✓" SEC="󰌾" SCAN="󰚫" MAN="󰀻" BACK="󰜺" EXIT="󰿅" POW="⏻" DISC="󰖪"

notify() {
  if command -v notify-send &>/dev/null; then
    notify-send "WiFi" "$1" -t "${2:-2000}" 2>/dev/null || true
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

  if ! command -v nmcli &>/dev/null; then
    echo "ERROR: nmcli is not installed" >&2
    missing=1
  fi

  if ! command -v wofi &>/dev/null; then
    echo "ERROR: wofi is not installed" >&2
    missing=1
  fi

  [[ $missing -eq 1 ]] && exit 1
  return 0
}

# NM helpers
wifi_on() { [[ $(nmcli -t -f WIFI g | cut -d: -f2) == "enabled" ]]; }
wifi_ifaces() { nmcli -t -f DEVICE,TYPE d | awk -F: '$2=="wifi"{print $1}'; }
iface_state() { nmcli -t -f DEVICE,STATE d | awk -F: -v i="$1" '$1==i{print $2}'; }
current_ssid() {
  nmcli -t -f DEVICE,CONNECTION d | awk -F: -v i="$1" '$1==i{
        gsub(/^[\047"]|[\047"]$/, "", $2); 
        print $2
    }'
}
connected_to() { [[ "$(current_ssid "$1")" == "$2" ]]; }

# Scanning
scan() {
  local iface="${1:-}" cache="$CACHE/wifi-${iface:-auto}"
  local cache_data="$CACHE/wifi-data-${iface:-auto}"

  [[ -f "$cache" && $(($(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0))) -lt 5 ]] && {
    cat "$cache"
    return
  }

  local cmd="nmcli --terse --fields IN-USE,SSID,BARS,SECURITY device wifi list"
  [[ -n "$iface" && "$iface" != "auto" ]] && cmd+=" ifname \"$iface\""

  >"$cache"
  >"$cache_data"

  local cnt=1
  eval "$cmd" 2>/dev/null | while IFS=: read -r use ssid bars sec; do
    [[ -z "$ssid" ]] && continue
    local s="$ssid" st=" " si=""
    ((${#s} > 26)) && s="${s:0:23}..."
    [[ "$use" == "*" ]] && st="$CON"
    [[ "$sec" != "--" && -n "$sec" ]] && si="$SEC"

    # Save display line
    echo "[${iface:-auto}] $bars $s $st $si" >>"$cache"

    # Save original SSID for parsing (line number → SSID mapping)
    echo "$cnt:$ssid" >>"$cache_data"
    ((cnt++))
  done

  [[ -s "$cache" ]] && cat "$cache" || echo "[${iface:-auto}] No networks"
}

# Get original SSID by line number
get_ssid_by_line() {
  local iface="$1" line_num="$2"
  local cache_data="$CACHE/wifi-data-${iface:-auto}"
  [[ -f "$cache_data" ]] || return 1
  awk -F: -v n="$line_num" '$1==n {print $2}' "$cache_data"
}

rescan() {
  rm -f "$CACHE/wifi-${1:-auto}" "$CACHE/wifi-data-${1:-auto}"
  if [[ -z "$1" || "$1" == "auto" ]]; then
    nmcli dev wifi rescan 2>/dev/null || true
  else
    nmcli dev wifi rescan ifname "$1" 2>/dev/null || true
  fi
  sleep 2
}

# Connection
connect() {
  local iface="$1" ssid="$2" pass="$3"

  ssid="${ssid#"${ssid%%[![:space:]]*}"}"
  ssid="${ssid%"${ssid##*[![:space:]]}"}"

  notify "Connecting to $ssid..." 1500

  local result exit_code
  if [[ -n "$pass" ]]; then
    if [[ -n "$iface" && "$iface" != "auto" ]]; then
      result=$(nmcli device wifi connect "$ssid" password "$pass" ifname "$iface" 2>&1)
      exit_code=$?
    else
      result=$(nmcli device wifi connect "$ssid" password "$pass" 2>&1)
      exit_code=$?
    fi
  else
    if [[ -n "$iface" && "$iface" != "auto" ]]; then
      result=$(nmcli device wifi connect "$ssid" ifname "$iface" 2>&1)
      exit_code=$?
    else
      result=$(nmcli device wifi connect "$ssid" 2>&1)
      exit_code=$?
    fi
  fi

  if [[ $exit_code -eq 0 ]]; then
    sleep 2
    local current_conn
    current_conn=$(current_ssid "${iface:-auto}")
    if [[ "$current_conn" == "$ssid" ]]; then
      notify "Connected to $ssid" 2000
      return 0
    else
      notify "Connected but verification failed" 3000
      return 0
    fi
  else
    local error_msg="${result##*Error:}"
    [[ -z "$error_msg" ]] && error_msg="Connection failed"
    notify "$error_msg" 3000
    return 1
  fi
}

disconnect() {
  if nmcli device disconnect "$1" &>/dev/null; then
    notify "Disconnected from $1" 2000
    return 0
  else
    notify "Failed to disconnect $1" 2000
    return 1
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

password_menu() {
  local result
  local wofi_cmd="wofi --dmenu --password -p \"$1\" --width \"$W\" --location \"$POS\" --xoffset \"$X\" --yoffset \"$Y\""

  # Add CSS if file exists
  [[ -f "$CSS_FILE" ]] && wofi_cmd+=" --style \"$CSS_FILE\""

  result=$(echo -e "$2" | eval "$wofi_cmd" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 1 ]]; then
    echo ""
    return 0
  elif [[ $exit_code -ne 0 ]]; then
    echo "ERROR: wofi password menu failed: $result" >&2
    echo ""
    return 1
  fi

  echo "$result"
  return 0
}

# Main interface menu
interface_menu() {
  if ! wifi_on; then
    local ch
    ch=$(menu "WiFi is disabled" "$POW Turn WiFi on\n$EXIT Exit")
    if [[ "$ch" == *"Turn WiFi on"* ]]; then
      nmcli radio wifi on && sleep 1
      exec "$0"
    fi
    return 0
  fi

  local ifaces items=""
  ifaces=$(wifi_ifaces)

  for i in $ifaces; do
    local st conn
    st=$(iface_state "$i")
    conn=$(current_ssid "$i")
    case "$st" in
    "connected" | "activated")
      items+="[$i] $WON ${conn:--}\n[$i] $DISC Disconnect\n"
      ;;
    "disconnected") items+="[$i] $WOFF Available\n" ;;
    "unavailable") items+="[$i] ⚠ Unavailable\n" ;;
    *) items+="[$i] ? $st\n" ;;
    esac
  done

  [[ -z "$ifaces" ]] && items+="No interfaces\n"
  items+="$SCAN Rescan all\n$MAN Manual\n$DISC Disconnect all\n$POW Turn off\n$EXIT Exit"

  local ch
  ch=$(menu "Select interface:" "$items")
  handle_interface_choice "$ch" "$ifaces"
}

handle_interface_choice() {
  local ch="$1" ifaces="$2"

  if [[ -z "$ch" ]]; then
    exit 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Turn off"* ]]; then
    nmcli radio wifi off
    notify "WiFi off" 2000
    exit 0
  elif [[ "$ch" == *"Rescan all"* ]]; then
    notify "Scanning..." 2000
    for i in $ifaces; do rescan "$i"; done
    sleep 1
    exec "$0"
  elif [[ "$ch" == *"Disconnect all"* ]]; then
    for i in $ifaces; do nmcli dev disconnect "$i" 2>/dev/null || true; done
    notify "Disconnected all" 2000
    sleep 1
    exec "$0"
  elif [[ "$ch" == *"Manual"* ]] && [[ ! "$ch" =~ ^\[ ]]; then
    manual_menu
    return 0
  fi

  if [[ "$ch" =~ ^\[([^]]+)\] ]]; then
    local iface="${BASH_REMATCH[1]}"

    if [[ "$ch" =~ Disconnect ]]; then
      disconnect "$iface"
      sleep 1
      exec "$0"
    elif [[ "$ch" =~ Unavailable ]]; then
      notify "Interface $iface is unavailable" 2000
      exec "$0"
    elif [[ "$ch" =~ Manual ]]; then
      manual_connect "$iface"
      return 0
    else
      network_menu "$iface"
      return 0
    fi
  fi

  exec "$0"
}

# Network menu - FIXED ORDER
network_menu() {
  local iface="$1"
  notify "Scanning..." 2000
  rescan "$iface"
  local nets
  nets=$(scan "$iface")

  [[ ! "$nets" =~ ^\[.*\]\ .*$ ]] && {
    iface="auto"
    nets=$(scan "auto")
  }

  # Build menu in EXPLICIT order: Back, Rescan, Manual, Exit, then networks
  # Using printf to ensure proper ordering
  local items=""
  items+="$BACK Back"
  items+=$'\n'"$SCAN Rescan"
  items+=$'\n'"$MAN Manual"
  items+=$'\n'"$EXIT Exit"

  # Add networks
  local cnt=1
  while IFS= read -r line; do
    items+=$'\n'"$cnt. $line"
    ((cnt++))
  done <<<"$nets"

  local ch
  ch=$(menu "[$iface] Select:" "$items")
  handle_network_choice "$ch" "$iface" "$nets"
}

handle_network_choice() {
  local ch="$1" iface="$2" nets="$3"

  if [[ -z "$ch" ]]; then
    exit 0
  fi

  if [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    exec "$0"
  elif [[ "$ch" == *"Rescan"* ]]; then
    rm -f "$CACHE/wifi-$iface" "$CACHE/wifi-data-$iface"
    notify "Scanning..." 2000
    sleep 2
    network_menu "$iface"
    return 0
  elif [[ "$ch" == *"Manual"* ]]; then
    manual_connect "$iface"
    return 0
  fi

  if [[ "$ch" =~ ^([0-9]+)\. ]]; then
    local num="${BASH_REMATCH[1]}" ssid

    ssid=$(get_ssid_by_line "$iface" "$num")

    if [[ -z "$ssid" ]]; then
      notify "Failed to get SSID" 2000
      exec "$0"
    fi

    if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
      connect "$iface" "$ssid" ""
    else
      local pass
      pass=$(password_menu "Password for $ssid:" "")
      if [[ -n "$pass" ]]; then
        connect "$iface" "$ssid" "$pass"
      else
        connect "$iface" "$ssid" ""
      fi
    fi
    sleep 1
    exec "$0"
  fi

  exec "$0"
}

# Manual connection
manual_menu() {
  local items=""
  for i in $(wifi_ifaces); do
    items+="[$i] Manual connect\n"
  done
  items+="$BACK Back\n$EXIT Exit"

  local ch
  ch=$(menu "Select interface for manual connection:" "$items")

  if [[ -z "$ch" ]]; then
    exit 0
  elif [[ "$ch" == *"Exit"* ]]; then
    exit 0
  elif [[ "$ch" == *"Back"* ]]; then
    exec "$0"
  elif [[ "$ch" =~ ^\[([^]]+)\] ]]; then
    manual_connect "${BASH_REMATCH[1]}"
    return 0
  fi

  exec "$0"
}

manual_connect() {
  local iface="$1" ssid pass

  ssid=$(menu "Enter SSID:" "")
  if [[ -z "$ssid" ]]; then
    exec "$0"
  fi

  pass=$(password_menu "Password for $ssid:" "")
  connect "$iface" "$ssid" "$pass"
  sleep 1
  exec "$0"
}

# Cleanup and main
cleanup() {
  find "$CACHE" -name "wifi-*" -mmin +10 -delete 2>/dev/null || true
  find "$CACHE" -name "wifi-data-*" -mmin +10 -delete 2>/dev/null || true
}
trap cleanup EXIT

main() {
  check_deps
  cleanup
  interface_menu
}

main "$@"
