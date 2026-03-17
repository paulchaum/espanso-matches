#!/bin/bash

# This script checks for an application's installation via Flatpak, Snap, and APT.

if [ -z "$1" ]; then
  echo "Usage: $0 <application_name>"
  exit 1
fi

APP_NAME="$1"

echo "### Checking for '$APP_NAME'..."
echo

echo "### Checking Flatpak..."
flatpak list | grep --color=never -i "$APP_NAME" || echo "'$APP_NAME' not found via Flatpak."
echo

echo "### Checking Snap..."
snap list | grep --color=never -i "$APP_NAME" || echo "'$APP_NAME' not found via Snap."
echo

echo "### Checking APT..."
# The '2>/dev/null' suppresses the APT CLI warning.
apt list --installed 2>/dev/null | grep --color=never -i "$APP_NAME" || echo "'$APP_NAME' not found via APT."
echo

echo "### Checking executable location..."
which "$APP_NAME" || echo "'$APP_NAME' executable not found in PATH."