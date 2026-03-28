#!/usr/bin/env bash
# ~/.config/wofi/wofi-wallpaper_selector.sh
# Depends on: wofi, swaybg, imagemagick (magick), libnotify

WALLPAPER_DIR="$HOME/Pictures/wallpapers/tokyonight-night/"
CACHE_DIR="$HOME/Pictures/wallpaper-selector/cache"
THUMBNAIL_WIDTH="250"
THUMBNAIL_HEIGHT="141"

mkdir -p "$CACHE_DIR"

generate_thumbnail() {
  local input="$1"
  local output="$2"
  magick "$input" -thumbnail "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}^" -gravity center -extent "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" "$output"
}

# Shuffle icon — вписываем в размер без обрезки, сохраняем прозрачность
SHUFFLE_ICON="$CACHE_DIR/shuffle_thumbnail.png"
magick -size "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" xc:"#1e2030" \
  \( "$HOME/Pictures/wallpaper-selector/shuffle_thumbnail.png" \
  -resize "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" \) \
  -gravity center -composite \
  "$SHUFFLE_ICON" 2>/dev/null

generate_menu() {
  # Shuffle entry — пустой info: чтобы текст не занимал место
  echo -en "img:$SHUFFLE_ICON\x00info:\x1fRANDOM\n"

  for img in "$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp}; do
    [[ -f "$img" ]] || continue
    thumbnail="$CACHE_DIR/$(basename "${img%.*}").png"
    if [[ ! -f "$thumbnail" ]] || [[ "$img" -nt "$thumbnail" ]]; then
      generate_thumbnail "$img" "$thumbnail"
    fi
    [[ -f "$thumbnail" ]] || continue
    # Пустой info: — текст не рендерится, места не занимает
    echo -en "img:$thumbnail\x00info:\x1f$img\n"
  done
}

selected=$(
  generate_menu | wofi --show dmenu \
    --cache-file /dev/null \
    --define "image-size=${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" \
    --columns 3 \
    --allow-images \
    --insensitive \
    --sort-order=default \
    --prompt "  Wallpaper" \
    --conf ~/.config/wofi/wallpaper.conf \
    --style ~/.config/wofi/wallpaper.css
)

[ -z "$selected" ] && exit 0

thumbnail_path="${selected#img:}"

if [[ "$thumbnail_path" == "$SHUFFLE_ICON" ]]; then
  original_path=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
else
  # Путь оригинала идёт после \x1f в selected
  original_path=$(printf '%s' "$selected" | sed 's/.*\x1f//')
  # Если не сработало — ищем по имени файла
  if [ -z "$original_path" ] || [ ! -f "$original_path" ]; then
    original_filename=$(basename "${thumbnail_path%.*}")
    original_path=$(find "$WALLPAPER_DIR" -type f -name "${original_filename}.*" | head -n1)
  fi
fi

[ -z "$original_path" ] || [ ! -f "$original_path" ] && exit 0

pkill swaybg 2>/dev/null
sleep 0.1
swaybg -i "$original_path" -m fill &

echo "$original_path" >"$HOME/.cache/current_wallpaper"
notify-send "Wallpaper" "$(basename "$original_path")" -i "$original_path"
