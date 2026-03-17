#!/bin/bash

PRINT_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --print|-p) PRINT_ONLY=true ;;
  esac
done

if [ -z "$1" ] || [[ "$1" == --* ]] || [[ "$1" == -* ]]; then
  echo "Usage: $0 <length> [--print|-p]"
  exit 1
fi

if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Length must be a positive integer."
  exit 1
fi

LENGTH=$1

PASSWORD=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$LENGTH")

if $PRINT_ONLY; then
  echo -n "$PASSWORD"
  exit 0
fi

# Copy to clipboard (cross-platform)
if command -v pbcopy >/dev/null 2>&1; then
  echo -n "$PASSWORD" | pbcopy
  echo "Password copied to clipboard." >&2
elif command -v xclip >/dev/null 2>&1; then
  echo -n "$PASSWORD" | xclip -selection clipboard
  echo "Password copied to clipboard." >&2
elif command -v wl-copy >/dev/null 2>&1; then
  echo -n "$PASSWORD" | wl-copy
  echo "Password copied to clipboard." >&2
else
  echo "Clipboard utility not found." >&2
fi

echo -n "$PASSWORD"
