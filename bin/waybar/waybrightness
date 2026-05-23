#!/usr/bin/env bash
# Audio visualizer for Waybar

BARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
CACHE_FILE="/tmp/waybar_audio_viz"
NUM_BARS=5
IDLE_BAR="▁▁▁▁▁"

get_volume() {
  pactl list sinks | awk '/Volume: front/ {gsub(/%/, "", $5); print $5; exit}'
}

max_height() {
  local vol=$1
  if [[ $vol -gt 70 ]]; then
    echo 7
  elif [[ $vol -gt 40 ]]; then
    echo 5
  elif [[ $vol -gt 20 ]]; then
    echo 4
  else
    echo 3
  fi
}

if ! playerctl status 2>/dev/null | grep -q "Playing"; then
  echo "$IDLE_BAR"
  rm -f "$CACHE_FILE"
  exit 0
fi

volume=$(get_volume)
max=$(max_height "$volume")

mapfile -t prev <"$CACHE_FILE" 2>/dev/null
[[ ${#prev[@]} -lt $NUM_BARS ]] && prev=(3 2 4 3 2)

output=""
new_vals=()

for ((i = 0; i < NUM_BARS; i++)); do
  val=$((prev[i] + (RANDOM % 5) - 2))
  ((val < 0)) && val=0
  ((val > max)) && val=$max
  new_vals+=("$val")
  output+="${BARS[$val]}"
done

printf "%s\n" "${new_vals[@]}" >"$CACHE_FILE"
echo "$output"
