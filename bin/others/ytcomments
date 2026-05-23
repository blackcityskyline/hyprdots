#!/usr/bin/env bash
# YouTube Comments Viewer
# ~/.config/rofi/scripts/yt-comments.sh
#
# Использование:
#   yt-comments.sh            — берёт URL из буфера обмена
#   yt-comments.sh <URL>      — явный URL
#
# Зависимости: yt-dlp, jq, rofi, wl-clipboard

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/yt-comments"
RASI="${HOME}/.config/rofi/launcher/launcher.rasi"
MAX_COMMENTS=100   # сколько комментариев загружать
COMMENT_WIDTH=80   # ширина текста для переноса

mkdir -p "$CACHE_DIR"

notify() {
  notify-send -t 3000 "YT Comments" "$1"
  echo "$1" >&2
}

# ── Получить video ID из URL ──────────────────────────────────────────────────
get_video_id() {
  python3 - "$1" <<'EOF'
import sys, urllib.parse
url = sys.argv[1].strip()
# youtu.be/ID
parsed = urllib.parse.urlparse(url)
if parsed.netloc in ("youtu.be",):
    print(parsed.path.lstrip("/").split("/")[0])
    sys.exit(0)
# youtube.com/watch?v=ID
qs = urllib.parse.parse_qs(parsed.query)
vid = qs.get("v", [""])[0]
if vid:
    print(vid)
    sys.exit(0)
# youtube.com/shorts/ID
parts = parsed.path.strip("/").split("/")
if len(parts) >= 2 and parts[0] in ("shorts", "live", "embed"):
    print(parts[1])
    sys.exit(0)
sys.exit(1)
EOF
}

# ── Загрузить комментарии через yt-dlp ───────────────────────────────────────
fetch_comments() {
  local video_id="$1" url="$2"
  local cache_file="$CACHE_DIR/${video_id}.info.json"

  # Используем кэш если свежее 1 часа
  if [ -f "$cache_file" ]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
    [ $age -lt 3600 ] && echo "$cache_file" && return 0
  fi

  notify "Loading comments..."

  yt-dlp \
    --write-comments \
    --extractor-args "youtube:comment_sort=top;max_comments=${MAX_COMMENTS};max_comment_depth=1" \
    --skip-download \
    --no-playlist \
    --no-write-thumbnail \
    --no-write-info-json \
    --write-info-json \
    --playlist-items 1 \
    -o "$CACHE_DIR/%(id)s.%(ext)s" \
    "$url" >/dev/null 2>&1

  local info_file="$CACHE_DIR/${video_id}.info.json"
  if [ ! -f "$info_file" ]; then
    notify "Failed to load comments"
    return 1
  fi

  echo "$info_file"
}

# ── Форматировать комментарии для rofi ───────────────────────────────────────
format_comments() {
  local json_file="$1"
  python3 - "$json_file" "$COMMENT_WIDTH" <<'EOF'
import json, sys, textwrap

path   = sys.argv[1]
width  = int(sys.argv[2])
sep    = "─" * width

with open(path) as f:
    data = json.load(f)

comments = data.get("comments", [])
# Топ-уровень сначала, потом ответы
top     = [c for c in comments if not c.get("parent") or c.get("parent") == "root"]
replies = [c for c in comments if c.get("parent") and c.get("parent") != "root"]

def fmt(c, indent=""):
    likes  = c.get("like_count", 0)
    author = c.get("author", "Unknown")
    text   = c.get("text", "").replace("\n", " ").strip()
    heart  = " ♥" if c.get("author_is_uploader") else ""
    lines  = textwrap.wrap(text, width - len(indent) - 2) or [""]
    header = f"{indent}👤 {author}{heart}  👍 {likes}"
    body   = f"\n{indent}  ".join(lines)
    return f"{header}\n{indent}  {body}"

lines = []
for c in top:
    lines.append(fmt(c))
    # Ответы на этот комментарий
    cid = c.get("id", "")
    for r in replies:
        if r.get("parent") == cid:
            lines.append(fmt(r, indent="    "))
    lines.append(sep)

print("\n".join(lines))
EOF
}

# ── Показать заголовок видео ──────────────────────────────────────────────────
get_title() {
  jq -r '.title // "Unknown title"' "$1" 2>/dev/null
}

# ── Получить URL из mpv через IPC ────────────────────────────────────────────
get_mpv_url() {
  [ -S "/tmp/mpvsocket" ] || return 1
  local url
  url=$(printf '{"command":["get_property","path"]}\n'     | socat - /tmp/mpvsocket 2>/dev/null     | jq -r '.data // empty')
  [ -n "$url" ] && echo "$url"
}

# ── Главная логика ────────────────────────────────────────────────────────────
# Приоритет: аргумент → mpv IPC → буфер обмена
if [ -n "${1:-}" ]; then
  URL="$1"
elif URL=$(get_mpv_url); then
  : # взяли из mpv
else
  URL=$(wl-paste 2>/dev/null)
fi

if [ -z "$URL" ]; then
  notify "No URL found (mpv not running and clipboard is empty)"
  exit 1
fi

VIDEO_ID=$(get_video_id "$URL")
if [ -z "$VIDEO_ID" ]; then
  notify "Not a YouTube URL: $URL"
  exit 1
fi

JSON_FILE=$(fetch_comments "$VIDEO_ID" "$URL")
if [ -z "$JSON_FILE" ]; then
  exit 1
fi

TITLE=$(get_title "$JSON_FILE")
FORMATTED=$(format_comments "$JSON_FILE")

if [ -z "$FORMATTED" ]; then
  notify "No comments found"
  exit 1
fi

# ── Viewer: fzf ───────────────────────────────────────────────────────────────
run_fzf() {
  if ! command -v fzf &>/dev/null; then
    notify "fzf not installed: sudo pacman -S fzf"
    exit 1
  fi
  if ! command -v foot &>/dev/null && ! command -v alacritty &>/dev/null; then
    notify "No terminal found (foot or alacritty)"
    exit 1
  fi

  # Скрипт для терминала
  local tmpscript
  tmpscript=$(mktemp /tmp/yt-fzf-XXXXXX.sh)
  local tmpdata
  tmpdata=$(mktemp /tmp/yt-fzf-XXXXXX.txt)

  printf '%s
' "$FORMATTED" > "$tmpdata"

  # preview скрипт — отдельный bash файл, избегаем проблем с fish и экранированием
  local tmppreview
  tmppreview=$(mktemp /tmp/yt-preview-XXXXXX.sh)

  cat > "$tmppreview" << HEREDOC
#!/usr/bin/env bash
sel="\$1"
awk -v sel="\$sel" '
  found && /^─+$/ { exit }
  \$0 == sel       { found=1 }
  found            { print }
' "$tmpdata" | fold -w 60 -s
HEREDOC
  chmod +x "$tmppreview"

  cat > "$tmpscript" << HEREDOC
#!/usr/bin/env bash
fzf \
  --prompt="💬 ${TITLE} > " \
  --preview="$tmppreview {}" \
  --preview-window="right:50%:wrap" \
  --bind="ctrl-c:abort,esc:abort,enter:abort" \
  --color="bg:#1a1b26,bg+:#24283b,fg:#c0caf5,fg+:#c0caf5,hl:#7aa2f7,hl+:#7dcfff,prompt:#7aa2f7,pointer:#f7768e,marker:#9ece6a,border:#414868" \
  --border=rounded \
  --margin=1,2 \
  --layout=reverse \
  < "$tmpdata"
rm -f "$tmppreview" "$tmpdata"
HEREDOC

chmod +x "$tmpscript"

  # Запускаем в floating терминале
  if command -v foot &>/dev/null; then
    foot --app-id=yt-comments --title="YT Comments" "$tmpscript"
  else
    alacritty --class yt-comments --title "YT Comments" -e "$tmpscript"
  fi
}

# ── Точка входа ────────────────────────────────────────────────────────────────
run_fzf