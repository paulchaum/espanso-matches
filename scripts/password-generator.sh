#!/bin/bash

# Check if length is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <length>"
  exit 1
fi

# Check if length is a positive integer
if ! [[ "$1" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Length must be a positive integer."
    exit 1
fi

LENGTH=$1

# Generate random string
PASSWORD=$(LC_ALL=C tr -dc 'a-zA-Z' < /dev/urandom | head -c "$LENGTH")

# Copy to clipboard (cross-platform)
if command -v pbcopy >/dev/null 2>&1; then
  echo -n "$PASSWORD" | pbcopy
  echo "Password copied to clipboard."
elif command -v xclip >/dev/null 2>&1; then
  echo -n "$PASSWORD" | xclip -selection clipboard
  echo "Password copied to clipboard."
elif command -v wl-copy >/dev/null 2>&1; then
  echo -n "$PASSWORD" | wl-copy
  echo "Password copied to clipboard."
else
  echo "Clipboard utility not found. Here is your password:"
  echo "$PASSWORD"
fi