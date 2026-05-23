#!/usr/bin/env bash
# CPU, temperature, RAM and disk monitor for Waybar

PREV_STAT_FILE="/tmp/cpu_stat_prev"

get_cpu_usage() {
  read -r _ user nice system idle iowait irq softirq steal _ _ <<<"$(grep '^cpu ' /proc/stat)"

  local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  local idle_now=$((idle + iowait))

  if [[ -f "$PREV_STAT_FILE" ]]; then
    read -r total_prev idle_prev <"$PREV_STAT_FILE"
    local dtotal=$((total - total_prev))
    local didle=$((idle_now - idle_prev))
    [[ $dtotal -gt 0 ]] && printf "%d" $((100 * (dtotal - didle) / dtotal)) || echo "0"
  else
    echo "0"
  fi

  echo "$total $idle_now" >"$PREV_STAT_FILE"
}

get_temp() {
  local cpu_drivers=("coretemp" "k10temp" "zenpower")

  for hwmon in /sys/class/hwmon/hwmon*; do
    local name
    name=$(cat "$hwmon/name" 2>/dev/null)
    local is_cpu=false
    for driver in "${cpu_drivers[@]}"; do
      [[ "$name" == "$driver" ]] && is_cpu=true && break
    done
    $is_cpu || continue

    local file="$hwmon/temp1_input"
    [[ -f "$file" ]] || continue
    local temp
    temp=$(cat "$file" 2>/dev/null)
    [[ -n "$temp" && "$temp" -gt 0 ]] && echo $((temp / 1000)) && return
  done

  # Fallback: ACPI thermal zone
  for file in /sys/class/thermal/thermal_zone*/temp; do
    [[ -f "$file" ]] || continue
    local type zone
    zone=$(dirname "$file")
    type=$(cat "$zone/type" 2>/dev/null)
    [[ "$type" == "x86_pkg_temp" || "$type" == "cpu-thermal" ]] || continue
    local temp
    temp=$(cat "$file" 2>/dev/null)
    [[ -n "$temp" && "$temp" -gt 0 ]] && echo $((temp / 1000)) && return
  done

  echo "0"
}

get_ram() {
  read -r total used _ <<<"$(free -b | awk '/^Mem:/ {print $2, $3}')"
  local used_gb total_gb percent=0
  used_gb=$(echo "scale=1; $used / 1073741824" | bc)
  total_gb=$(echo "scale=1; $total / 1073741824" | bc)
  [[ $total -gt 0 ]] && percent=$((100 * used / total))
  echo "$used_gb $total_gb $percent"
}

get_disk() {
  read -r used_bytes total_bytes percent \
    <<<"$(df -B1 / --output=used,size,pcent 2>/dev/null | tail -1 | tr -d '%')"
  local used_gb total_gb
  used_gb=$(echo "scale=1; $used_bytes / 1073741824" | bc)
  total_gb=$(echo "scale=1; $total_bytes / 1073741824" | bc)
  echo "$used_gb $total_gb $percent"
}

# --- main ---

cpu=$(get_cpu_usage)
temp=$(get_temp)
read -r ram_used ram_total ram_pct <<<"$(get_ram)"
read -r disk_used disk_total disk_pct <<<"$(get_disk)"

[[ "$temp" == "0" ]] && display="${cpu}%" || display="${temp}°C ${cpu}%"

class="normal"
if [[ $temp -gt 80 || $cpu -gt 95 || $ram_pct -gt 95 || $disk_pct -gt 95 ]]; then
  class="critical"
elif [[ $temp -gt 70 || $cpu -gt 80 || $ram_pct -gt 85 || $disk_pct -gt 85 ]]; then
  class="warning"
fi

ram_used=${ram_used%.0}
ram_total=${ram_total%.0}
disk_used=${disk_used%.0}
disk_total=${disk_total%.0}

tooltip="CPU: ${cpu}%\nTemp: ${temp}°C\nRAM: ${ram_used}/${ram_total} GB (${ram_pct}%)\nDisk: ${disk_used}/${disk_total} GB (${disk_pct}%)"

echo "{\"text\": \"$display\", \"class\": \"$class\", \"tooltip\": \"$tooltip\"}"
