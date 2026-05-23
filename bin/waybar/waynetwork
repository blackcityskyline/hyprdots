#!/usr/bin/env bash
# WiFi monitor for Waybar

INTERFACES=(wlan0 wlan1)

wifi_info=""
active_ssid=""
has_connection=false

for iface in "${INTERFACES[@]}"; do
  link_info=$(iw dev "$iface" link 2>/dev/null) || continue
  echo "$link_info" | grep -q "Connected" || continue

  has_connection=true

  ssid=$(echo "$link_info" | awk '/SSID:/    {print $2}')
  signal=$(echo "$link_info" | awk '/signal:/  {print $2}')
  freq=$(echo "$link_info" | awk '/freq:/    {print $2}')
  ip=$(ip -4 addr show "$iface" 2>/dev/null |
    grep -oE 'inet [0-9.]+' | head -1 | cut -d' ' -f2)

  [[ -n "$freq" ]] &&
    freq_info=", $(echo "scale=1; $freq / 1000" | bc) GHz" ||
    freq_info=""

  [[ -z "$ip" ]] && ip="No IP"
  [[ -z "$active_ssid" ]] && active_ssid="$ssid"

  wifi_info+="${iface}: ${ssid} (${signal} dBm${freq_info}) ${ip}\n"
done

if [[ "$has_connection" == true ]]; then
  text="󰖩 "
  tooltip=$(printf "%b" "$wifi_info" | head -n 2 | sed 's/"/\\"/g' | paste -sd '\\n')
else
  text="󰖪 "
  tooltip="No active connections"
fi

printf '{"text": "%s", "tooltip": "%s"}\n' "$text" "$tooltip"
