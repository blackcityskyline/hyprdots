#!/usr/bin/env bash
# System update manager for Arch Linux / Waybar

[[ -f /etc/arch-release ]] || exit 0

# --- config ---

TITLE="Arch Linux Update"
TERMINALS=(kitty alacritty foot gnome-terminal xterm)

ASCII_ART='
  ▄▄▄· ▄▄▄   ▄▄·  ▄ .▄
 ▐█ ▀█ ▀▄ █·▐█ ▌▪██▪▐█
 ▄█▀▀█ ▐▀▀▄ ██ ▄▄██▀▐█
 ▐█ ▪▐▌▐█•█▌▐███▌██▌▐▀
  ▀  ▀ .▀  ▀·▀▀▀ ▀▀▀ ·
  ┬ ┬┌─┐┌┬┐┌─┐┌┬┐┌─┐
  │ │├─┘ ││├─┤ │ ├┤
  └─┘┴  ─┴┘┴ ┴ ┴ └─┘
'

# --- helpers ---

pkg_installed() {
  pacman -Qi "$1" &>/dev/null || command -v "$1" &>/dev/null
}

cargo_ok() {
  command -v cargo &>/dev/null && cargo --version &>/dev/null
}

get_aur_helper() {
  if pkg_installed yay; then
    echo "yay"
  elif pkg_installed paru; then
    echo "paru"
  fi
}

open_terminal() {
  local cmd="\"$0\" _run"
  for term in "${TERMINALS[@]}"; do
    command -v "$term" &>/dev/null || continue
    case "$term" in
    kitty) kitty --title "$TITLE" sh -c "$cmd" ;;
    alacritty) alacritty --title "$TITLE" -e sh -c "$cmd" ;;
    foot) foot --title "$TITLE" sh -c "$cmd" ;;
    gnome-terminal) gnome-terminal --title="$TITLE" -- sh -c "$cmd" ;;
    xterm) xterm -title "$TITLE" -e sh -c "$cmd" ;;
    esac
    return
  done
  notify-send "$TITLE" "No terminal emulator found (install kitty, alacritty, etc.)"
}

# --- update counts ---
# Sets variables: official, aur, flatpak_n, cargo_n, total

count_updates() {
  local aur_helper
  aur_helper=$(get_aur_helper)

  official=$(checkupdates 2>/dev/null | wc -l)
  aur=0
  flatpak_n=0
  cargo_n=0

  [[ -n "$aur_helper" ]] && aur=$("$aur_helper" -Qua 2>/dev/null | wc -l)

  pkg_installed flatpak &&
    flatpak_n=$(flatpak remote-ls --updates 2>/dev/null | wc -l)

  if cargo_ok && cargo install-update --help &>/dev/null 2>&1; then
    cargo_n=$(cargo install-update -a --list 2>/dev/null | grep -c "Yes")
  fi

  total=$((official + aur + flatpak_n + cargo_n))
}

# --- modes ---

mode_check() {
  # Quick JSON output for Waybar
  count_updates
  local aur_helper tooltip
  aur_helper=$(get_aur_helper)
  tooltip="Pacman: $official\nAUR (${aur_helper:-none}): $aur\nFlatpak: $flatpak_n\nCargo: $cargo_n\n\nTotal: $total"

  if [[ $total -eq 0 ]]; then
    echo '{"text": "󰣇", "tooltip": "All packages up to date"}'
  else
    echo "{\"text\": \"󰣇 $total\", \"tooltip\": \"${tooltip//\"/\\\"}\", \"class\": \"updates\"}"
  fi
}

mode_up() {
  # Open terminal; signal Waybar to refresh on exit
  trap 'pkill -RTMIN+20 waybar' EXIT
  open_terminal
}

mode_run() {
  # Interactive update session — runs inside the terminal
  clear
  printf "%s\n" "$ASCII_ART"
  echo "🔍 Checking for updates..."
  echo ""

  count_updates
  local aur_helper
  aur_helper=$(get_aur_helper)

  printf "📦 Pacman:  %s\n" "$official"
  printf "📦 AUR:     %s (%s)\n" "$aur" "${aur_helper:-no helper}"
  printf "📦 Flatpak: %s\n" "$flatpak_n"
  printf "📦 Cargo:   %s\n" "$cargo_n"
  echo "────────────────────────────────────────"
  printf "📦 Total:   %s\n" "$total"
  echo ""

  if [[ $total -eq 0 ]]; then
    echo "✅ Already up to date!"
    read -rn1 -p "Press any key..."
    return
  fi

  read -rn1 -p "Press any key to update or Ctrl+C to cancel..."
  echo ""

  if [[ -n "$aur_helper" ]]; then
    echo "🔄 $aur_helper -Syu"
    echo "────────────────────────────────────────"
    "$aur_helper" -Syu --noconfirm
  else
    echo "🔄 sudo pacman -Syu"
    echo "────────────────────────────────────────"
    sudo pacman -Syu --noconfirm
  fi

  if pkg_installed flatpak; then
    echo ""
    echo "🔄 flatpak update"
    echo "────────────────────────────────────────"
    flatpak update -y
  fi

  if cargo_ok && cargo install-update --help &>/dev/null 2>&1; then
    echo ""
    echo "🔄 cargo install-update -a"
    echo "────────────────────────────────────────"
    cargo install-update -a
  fi

  echo ""
  echo "✅ Done!"
  read -rn1 -p "Press any key..."
}

mode_upgrade() {
  # Detailed status output in terminal
  count_updates
  local aur_helper
  aur_helper=$(get_aur_helper)

  printf "%s\n" "$ASCII_ART"
  printf "Pacman:   %s\n" "$official"
  printf "AUR:      %s (%s)\n" "$aur" "${aur_helper:-no helper}"
  printf "Flatpak:  %s\n" "$flatpak_n"
  printf "Cargo:    %s\n" "$cargo_n"
  echo "════════════════════════════════════════"
  printf "Total:    %s\n" "$total"
  echo "════════════════════════════════════════"
}

mode_menu() {
  printf "%s\n" "$ASCII_ART"
  echo "  1) check    — Waybar status"
  echo "  2) up       — run updates"
  echo "  3) upgrade  — detailed status"
  echo "  4) exit"
  echo ""
  read -rp "  > " choice
  echo ""
  case "$choice" in
  1 | check) exec "$0" check ;;
  2 | up) mode_run ;;          # уже в терминале — запускаем напрямую
  3 | upgrade) mode_upgrade ;; # то же самое
  esac
}

# --- dispatch ---

case "$1" in
check) mode_check ;;
up) mode_up ;;
_run) mode_run ;;
upgrade) mode_upgrade ;;
"") mode_menu ;;
*) mode_check ;;
esac
