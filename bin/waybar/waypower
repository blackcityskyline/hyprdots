#!/usr/bin/env bash
# Power menu for Waybar

SWAYLOCK_ARGS=(-f -c 000000)

run_wlogout() {
  wlogout -b 5 -m 304 --margin-left 283 --margin-right 283
}

run_rofi() {
  local chosen
  chosen=$(printf " Lock\n󰌾 Logout\n󰒲 Suspend\n󰜉 Reboot\n⏻ Shutdown" |
    rofi -dmenu -i -p "Power Menu:" -theme-str '* { font: "JetBrains Mono 12"; }')

  case "$chosen" in
  *Lock) swaylock "${SWAYLOCK_ARGS[@]}" ;;
  *Logout) hyprctl dispatch exit ;;
  *Suspend) systemctl suspend ;;
  *Reboot) systemctl reboot ;;
  *Shutdown) systemctl poweroff ;;
  esac
}

if command -v wlogout &>/dev/null; then
  run_wlogout
elif command -v rofi &>/dev/null; then
  run_rofi
else
  notify-send "Power Menu" "Install wlogout or rofi"
fi
