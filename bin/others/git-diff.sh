#!/bin/bash
# ~/bin/git-diff.sh
# Usage:
#   git-diff.sh                                  — show status (default repo)
#   git-diff.sh --repo or -r <repository>        — use hyprdots repo
#   git-diff.sh --diff or -d                     — show full diff
#   git-diff.sh --sync or -s                     — sync changes to repo

# Re-exec as root to avoid per-call sudo overhead
if [[ $EUID -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

USER_HOME="/home/black"
REPOS_BASE="$USER_HOME/git/personal"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -------------------------------------------------------
# Parse args
# -------------------------------------------------------
REPO_NAME="dotfiles"
SHOW_DIFF=false
SYNC=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  --repo | -r)
    REPO_NAME="$2"
    shift 2
    ;;
  --diff | -d)
    SHOW_DIFF=true
    shift
    ;;
  --sync | -s)
    SYNC=true
    shift
    ;;
  *) shift ;;
  esac
done

DOTFILES="$REPOS_BASE/$REPO_NAME"

if [[ ! -d "$DOTFILES/.git" ]]; then
  echo -e "${RED}error: $DOTFILES is not a git repo${NC}"
  exit 1
fi

# -------------------------------------------------------
# Mappings for each repository
# -------------------------------------------------------
declare -A ROOTS
declare -A FILES

case "$REPO_NAME" in
dotfiles | hyprdots)
  ROOTS=(
    [".config"]="$USER_HOME/.config"
    [".local"]="$USER_HOME/.local"
    [".themes"]="$USER_HOME/.themes"
    ["bin"]="$USER_HOME/bin"
    ["usr"]="/usr"
    ["etc"]="/etc"
  )
  FILES=(
    [".bashrc"]="$USER_HOME/.bashrc"
  )
  ;;
shell-scripts)
  ROOTS=(
    ["bin"]="$USER_HOME/bin"
    ["bash"]="$USER_HOME/apps/shell-scripts"
    ["fish"]="$USER_HOME/.config/fish/functions"
  )
  ;;
*)
  echo -e "${RED}error: unknown repo '$REPO_NAME'${NC}"
  echo -e "available: dotfiles, hyprdots, shell-scripts"
  exit 1
  ;;
esac

# Ignore paths to avoid missing errors
IGNORE_PATHS=(
  "$DOTFILES/preview"
  "$DOTFILES/wallpapers"
)

CHANGED=()
MISSING_IN_SYSTEM=()

echo -e "${BOLD}=== dotfiles diff ===${NC}"
echo -e "repo: ${CYAN}$DOTFILES${NC}\n"

# -------------------------------------------------------
# Difference in file
# -------------------------------------------------------
check_file() {
  local REPO_FILE="$1"
  local SYS_FILE="$2"

  if [[ ! -e "$SYS_FILE" ]]; then
    MISSING_IN_SYSTEM+=("$REPO_FILE|$SYS_FILE")
  elif ! diff -q "$REPO_FILE" "$SYS_FILE" &>/dev/null 2>&1; then
    CHANGED+=("$REPO_FILE|$SYS_FILE")
  fi
}

# -------------------------------------------------------
# Repository check
# -------------------------------------------------------
for REPO_REL in "${!ROOTS[@]}"; do
  REPO_ROOT="$DOTFILES/$REPO_REL"
  SYS_ROOT="${ROOTS[$REPO_REL]}"
  [[ ! -d "$REPO_ROOT" ]] && continue
  while IFS= read -r -d '' REPO_FILE; do
    REL="${REPO_FILE#$REPO_ROOT/}"
    SYS_FILE="$SYS_ROOT/$REL"
    # Skip ignored paths
    SKIP=false
    for IGN in "${IGNORE_PATHS[@]}"; do
      [[ "$REPO_FILE" == "$IGN"* ]] && SKIP=true && break
    done
    $SKIP && continue
    check_file "$REPO_FILE" "$SYS_FILE"
  done < <(find "$REPO_ROOT" -type f -print0 2>/dev/null)
done

for FILE_REL in "${!FILES[@]}"; do
  REPO_FILE="$DOTFILES/$FILE_REL"
  SYS_FILE="${FILES[$FILE_REL]}"
  [[ -f "$REPO_FILE" ]] && check_file "$REPO_FILE" "$SYS_FILE"
done

# -------------------------------------------------------
# Display modified
# -------------------------------------------------------
if [[ ${#CHANGED[@]} -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}modified:${NC}"
  for ENTRY in "${CHANGED[@]}"; do
    REPO_FILE="${ENTRY%%|*}"
    SYS_FILE="${ENTRY##*|}"
    REL="${SYS_FILE/$USER_HOME/~}"
    echo -e "  ${YELLOW}~${NC} $REL"
    if $SHOW_DIFF; then
      diff --color=always -u "$REPO_FILE" "$SYS_FILE" 2>/dev/null | tail -n +3
      echo ""
    fi
  done
  echo ""
else
  echo -e "${GREEN}nothing changed${NC}\n"
fi

# -------------------------------------------------------
# Display missing
# -------------------------------------------------------
if [[ ${#MISSING_IN_SYSTEM[@]} -gt 0 ]]; then
  echo -e "${RED}${BOLD}missing in system:${NC}"
  for ENTRY in "${MISSING_IN_SYSTEM[@]}"; do
    SYS_FILE="${ENTRY##*|}"
    REL="${SYS_FILE/$USER_HOME/~}"
    echo -e "  ${RED}-${NC} $REL"
  done
  echo ""
fi

# -------------------------------------------------------
# Status
# -------------------------------------------------------
TOTAL_FILES=0
for REPO_REL in "${!ROOTS[@]}"; do
  REPO_ROOT="$DOTFILES/$REPO_REL"
  [[ ! -d "$REPO_ROOT" ]] && continue
  COUNT=$(find "$REPO_ROOT" -type f 2>/dev/null | wc -l)
  TOTAL_FILES=$((TOTAL_FILES + COUNT))
done
for FILE_REL in "${!FILES[@]}"; do
  [[ -f "$DOTFILES/$FILE_REL" ]] && TOTAL_FILES=$((TOTAL_FILES + 1))
done
SYNCED=$((TOTAL_FILES - ${#CHANGED[@]} - ${#MISSING_IN_SYSTEM[@]}))

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  $REPO_NAME / status${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  checked       ${BOLD}${TOTAL_FILES}${NC} files"
echo -e "  up to date    ${GREEN}${SYNCED} ✓${NC}"
echo -e "  modified      ${YELLOW}${#CHANGED[@]} ~${NC}"
echo -e "  missing       ${RED}${#MISSING_IN_SYSTEM[@]} ✗${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ ${#CHANGED[@]} -gt 0 ]]; then
  $SHOW_DIFF || echo -e "\n  ${CYAN}tip: run with --diff to see changes${NC}"
  echo -e "  ${YELLOW}run with --sync to update repo${NC}"
elif [[ ${#MISSING_IN_SYSTEM[@]} -eq 0 ]]; then
  echo -e "\n  ${GREEN}everything is up to date${NC}"
fi
echo ""

# -------------------------------------------------------
# Sync
# -------------------------------------------------------
if $SYNC; then
  if [[ ${#CHANGED[@]} -eq 0 && ${#MISSING_IN_SYSTEM[@]} -eq 0 ]]; then
    echo -e "${GREEN}nothing to sync${NC}"
    exit 0
  fi

  if [[ ${#CHANGED[@]} -gt 0 ]]; then
    echo -e "${BOLD}syncing to repo...${NC}"
    for ENTRY in "${CHANGED[@]}"; do
      REPO_FILE="${ENTRY%%|*}"
      SYS_FILE="${ENTRY##*|}"
      cp "$SYS_FILE" "$REPO_FILE"
      REL="${SYS_FILE/$USER_HOME/~}"
      echo -e "  ${YELLOW}↻${NC} $REL"
    done
  fi

  if [[ ${#MISSING_IN_SYSTEM[@]} -gt 0 ]]; then
    echo -e "\n${RED}${BOLD}missing in system — remove from repo?${NC}"
    for ENTRY in "${MISSING_IN_SYSTEM[@]}"; do
      REPO_FILE="${ENTRY%%|*}"
      SYS_FILE="${ENTRY##*|}"
      REL="${SYS_FILE/$USER_HOME/~}"

      SYS_DIR=$(dirname "$SYS_FILE")
      RENAMED=""
      if [[ -d "$SYS_DIR" ]]; then
        while IFS= read -r -d '' CANDIDATE; do
          if diff -q "$REPO_FILE" "$CANDIDATE" &>/dev/null 2>&1; then
            RENAMED="$CANDIDATE"
            break
          fi
        done < <(find "$SYS_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
      fi

      if [[ -n "$RENAMED" ]]; then
        RENAMED_REL="${RENAMED/$USER_HOME/~}"
        echo -ne "  ${YELLOW}?${NC} $REL → renamed to ${BOLD}$RENAMED_REL${NC}? rename in repo? ${BOLD}[y/N]${NC} "
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          mv "$REPO_FILE" "$(dirname "$REPO_FILE")/$(basename "$RENAMED")"
          echo -e "  ${YELLOW}↻${NC} renamed in repo"
        fi
      else
        echo -ne "  ${RED}-${NC} $REL ${BOLD}[y/N]${NC} "
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          rm -f "$REPO_FILE"
          echo -e "  ${RED}✗${NC} removed from repo"
        fi
      fi
    done
  fi

  echo -e "\n${GREEN}done. run git-push.sh to push${NC}"
fi
