#!/bin/bash
# ~/bin/git-dots.sh
# Usage:
#   git-push.sh                             — push dotfiles (default)
#   git-push.sh --repo or -r <repository>   — push changes to selected repo name
#   git push.sh --<repository>              — push changes to selected repo name

USER_HOME="/home/black"
REPOS_BASE="$USER_HOME/git/personal"
REPO_NAME="dotfiles"
LOG="$USER_HOME/.cache/log/cron.log"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --repo | -r)
    REPO_NAME="$2"
    shift 2
    ;;
  --dotfiles)
    REPO_NAME="dotfiles"
    shift
    ;;
  --hyprdots)
    REPO_NAME="hyprdots"
    shift
    ;;
  --shell-scripts)
    REPO_NAME="shell-scripts"
    shift
    ;;
  *) shift ;;
  esac
done

DOTFILES="$REPOS_BASE/$REPO_NAME"

# Change dir
cd "$DOTFILES" || {
  echo "$(date) - ERROR: Cannot cd to $DOTFILES" >>"$LOG"
  exit 1
}

# Check if repository is git
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "$(date) - ERROR: Not a git repository: $DOTFILES" >>"$LOG"
  exit 1
fi

# Save list
CHANGES_BEFORE=$(git status --porcelain)

# Add changes
git add -A

# Check commit
if git diff --cached --quiet; then
  echo "$(date) - [$REPO_NAME] No changes to commit" >>"$LOG"
  exit 0
fi

# Commit
if git commit -m "Sync $(date +%Y-%m-%d)"; then
  COMMIT_STATUS="OK"
else
  COMMIT_STATUS="FAILED"
fi

# Push
if git push origin main; then
  PUSH_STATUS="OK"
else
  PUSH_STATUS="FAILED"
fi

# Logs
{
  echo "---"
  echo "$(date) - [$REPO_NAME] Sync attempt"
  echo "Changes before add:"
  echo "$CHANGES_BEFORE"
  echo "Commit status: $COMMIT_STATUS"
  echo "Push status: $PUSH_STATUS"
  echo "---"
} >>"$LOG"
