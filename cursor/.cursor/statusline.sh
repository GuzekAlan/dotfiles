#!/usr/bin/env bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
MODEL_ID=$(echo "$input" | jq -r '.model.id // ""')
PARAMS=$(echo "$input" | jq -r '.model.param_summary // empty')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
IN_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
WT=$(echo "$input" | jq -r '.worktree.name // empty')

# Colors
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
MAGENTA='\033[35m'
GRAY='\033[90m'
RED='\033[31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Model pricing ($ per million tokens — input / output)
case "$MODEL_ID" in
  *opus*)    IN_PRICE=15;    OUT_PRICE=75    ;;
  *sonnet*)  IN_PRICE=3;     OUT_PRICE=15    ;;
  *haiku*)   IN_PRICE=0.25;  OUT_PRICE=1.25  ;;
  *gpt-4o*)  IN_PRICE=2.5;   OUT_PRICE=10    ;;
  *gpt-4*)   IN_PRICE=5;     OUT_PRICE=15    ;;
  *gpt-3*)   IN_PRICE=0.5;   OUT_PRICE=1.5   ;;
  *)         IN_PRICE=3;     OUT_PRICE=15    ;;
esac

COST=$(LC_NUMERIC=C awk -v i="$IN_TOKENS" -v o="$OUT_TOKENS" -v ip="$IN_PRICE" -v op="$OUT_PRICE" \
  'BEGIN { printf "%.4f", (i * ip + o * op) / 1000000 }')
COST_FMT=$(LC_NUMERIC=C awk -v c="$COST" 'BEGIN {
  if (c < 0.005) print "< $0.01"
  else printf "$%.2f", c
}')

# Context bar (green → yellow → red by usage)
BAR_WIDTH=12
FILLED=$((PCT * BAR_WIDTH / 100))
N_EMPTY=$((BAR_WIDTH - FILLED))
BAR_FILLED=""; BAR_EMPTY=""
[ "$FILLED" -gt 0 ] && printf -v BAR_FILLED "%${FILLED}s" && BAR_FILLED="${BAR_FILLED// /▓}"
[ "$N_EMPTY" -gt 0 ] && printf -v BAR_EMPTY "%${N_EMPTY}s" && BAR_EMPTY="${BAR_EMPTY// /░}"
CTX_BAR="${BAR_FILLED}${BAR_EMPTY}"

if   [ "$PCT" -ge 80 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 50 ]; then BAR_COLOR="$YELLOW"
else                         BAR_COLOR="$GREEN"
fi

# Git branch
BRANCH=""
if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir &>/dev/null; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi

# PR info — cached for 60s to avoid slow gh API calls on every update
PR_DISPLAY=""
if [ -n "$BRANCH" ] && [ -n "$DIR" ] && command -v gh &>/dev/null; then
  CACHE_FILE="/tmp/.cursor-pr-${DIR##*/}-${BRANCH//\//-}"
  USE_CACHE=""
  if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    [ "$CACHE_AGE" -lt 60 ] && USE_CACHE=1
  fi
  if [ -n "$USE_CACHE" ]; then
    PR_TEXT=$(cat "$CACHE_FILE")
  else
    PR_TEXT=$(cd "$DIR" && gh pr view --json number,title --jq '"#\(.number)  \(.title)"' 2>/dev/null | xargs || echo "")
    echo "$PR_TEXT" > "$CACHE_FILE"
  fi
  if [ -n "$PR_TEXT" ]; then
    [ ${#PR_TEXT} -gt 58 ] && PR_TEXT="${PR_TEXT:0:58}…"
    PR_DISPLAY="  ${GRAY}→${RESET} ${MAGENTA}${PR_TEXT}${RESET}"
  fi
fi

# Assemble line 1: location (project · branch → PR · worktree)
BRANCH_STR=""
[ -n "$BRANCH" ] && BRANCH_STR="  ${BLUE}${BRANCH}${RESET}"

WT_STR=""
[ -n "$WT" ] && WT_STR="  ${YELLOW}wt:${WT}${RESET}"

# Assemble line 2: model · context bar · cost
MODEL_STR="${GRAY}${MODEL}${RESET}"
[ -n "$PARAMS" ] && MODEL_STR="${GRAY}${MODEL} ${DIM}${PARAMS}${RESET}"

echo -e "${CYAN}${BOLD}${DIR##*/}${RESET}${BRANCH_STR}${PR_DISPLAY}${WT_STR}"
echo -e "${MODEL_STR}  ${BAR_COLOR}${CTX_BAR}${RESET} ${GRAY}${PCT}%  ${YELLOW}${COST_FMT}${RESET}${GRAY} this session${RESET}"
