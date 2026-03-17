#!/bin/bash
TARGET_BRANCH="${1:-remotes/origin/main}"
REMOTE="origin"
# Colors
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
WHITE="\033[97m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
GREEN="\033[32m"
BG_HEADER="\033[48;5;236m"
# Git branch -a color convention
COLOR_LOCAL="\033[37m"       # white  — local branches
COLOR_REMOTE="\033[31m"      # red    — remote branches
COLOR_CURRENT="\033[32m"     # green  — current checked-out branch

# Column positions
COL_BRANCH=2
COL_TYPE=52
COL_BEHIND=62
COL_AHEAD=72
COL_DATE=82

CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)

move_col() { echo -en "\033[${1}G"; }

color_branch() {
  local name="$1"
  local type="$2"   # "local" or "remote"
  if [ "$type" = "local" ] && [ "$name" = "$CURRENT_BRANCH" ]; then
    echo -en "${COLOR_CURRENT}* ${name}${RESET}"
  elif [ "$type" = "remote" ]; then
    echo -en "${COLOR_REMOTE}${name}${RESET}"
  else
    echo -en "${COLOR_LOCAL}${name}${RESET}"
  fi
}

color_behind() {
  local n=$1
  if   [ "$n" -eq 0 ];  then echo -en "${GREEN}${n}${RESET}"
  elif [ "$n" -lt 10 ]; then echo -en "${YELLOW}${n}${RESET}"
  elif [ "$n" -lt 50 ]; then echo -en "${RED}${n}${RESET}"
  else                       echo -en "${BOLD}${RED}${n}${RESET}"
  fi
}

color_ahead() {
  local n=$1
  if   [ "$n" -eq 0 ]; then echo -en "${DIM}${n}${RESET}"
  elif [ "$n" -lt 5 ];  then echo -en "${CYAN}${n}${RESET}"
  else                       echo -en "${BOLD}${CYAN}${n}${RESET}"
  fi
}

color_date() {
  local d="$1"
  if   echo "$d" | grep -qE "^[0-9]+ (second|minute)"; then echo -en "${GREEN}${d}${RESET}"
  elif echo "$d" | grep -qE "^[0-9]+ hour";             then echo -en "${CYAN}${d}${RESET}"
  elif echo "$d" | grep -qE "^[0-9]+ day";              then echo -en "${YELLOW}${d}${RESET}"
  else                                                        echo -en "${DIM}${d}${RESET}"
  fi
}

print_row() {
  local display_name="$1"
  local type="$2"
  local behind="$3"
  local ahead="$4"
  local date="$5"
  echo -en "\n"
  move_col $COL_BRANCH;  color_branch "$display_name" "$type"
  move_col $COL_TYPE;    echo -en "${DIM}${type}${RESET}"
  move_col $COL_BEHIND;  color_behind "$behind"
  move_col $COL_AHEAD;   color_ahead  "$ahead"
  move_col $COL_DATE;    color_date   "$date"
}

process_refs() {
  local refs_path="$1"
  local type_label="$2"
  local strip_prefix="$3"
  git for-each-ref \
    --format='%(refname:short) %(committerdate:relative)' \
    --sort=-committerdate \
    "$refs_path" \
    | grep -v 'HEAD' \
    | while IFS= read -r line; do
        branch=$(echo "$line" | awk '{print $1}')
        relative_date=$(echo "$line" | cut -d' ' -f2-)
        # Display name: keep remotes/origin/... prefix for remote, short for local
        if [ "$type_label" = "remote" ]; then
          display_name="remotes/${branch}"
        else
          display_name="${branch}"
        fi
        if [ "$branch" = "$TARGET_BRANCH" ] || [ "$display_name" = "$TARGET_BRANCH" ]; then
          continue
        fi
        behind=$(git rev-list --count "$branch".."$TARGET_BRANCH" 2>/dev/null) || continue
        ahead=$(git rev-list  --count "$TARGET_BRANCH".."$branch" 2>/dev/null) || continue
        print_row "$display_name" "$type_label" "$behind" "$ahead" "$relative_date"
      done
}

git fetch --all -q

echo ""
echo -e "${BG_HEADER}${BOLD}${WHITE}  Target branch : ${CYAN}${TARGET_BRANCH}${RESET}"
echo ""

# Header
echo -en "${BG_HEADER}${BOLD}${WHITE}"
move_col $COL_BRANCH;  echo -en "Branch"
move_col $COL_TYPE;    echo -en "Type"
move_col $COL_BEHIND;  echo -en "Behind"
move_col $COL_AHEAD;   echo -en "Ahead"
move_col $COL_DATE;    echo -en "Last Update"
echo -e "${RESET}"

# Separator
echo -en "${DIM}"
move_col $COL_BRANCH;  echo -en "$(printf '%.0s-' {1..48})"
move_col $COL_TYPE;    echo -en "--------"
move_col $COL_BEHIND;  echo -en "--------"
move_col $COL_AHEAD;   echo -en "--------"
move_col $COL_DATE;    echo -en "--------------------"
echo -e "${RESET}"

# Remote branches
process_refs "refs/remotes/$REMOTE" "remote" "$REMOTE/"
# Local branches
process_refs "refs/heads" "local" ""

echo -e "\n"