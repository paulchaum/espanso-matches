#!/bin/bash

set -e

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_pdf>"
    exit 1
fi

INPUT_PATH="$1"
FILENAME=$(basename "$INPUT_PATH")
BASENAME="${FILENAME%.*}"
OUTPUT_FILE="${BASENAME}_burn.pdf"

# Create a secure temporary directory
TEMP_DIR=$(mktemp -d)

# Convert PDF pages to PNG images
pdftoppm -progress -r 300 -png "$INPUT_PATH" "$TEMP_DIR/burn"

# Convert images back to PDF
# Using sort -V to ensure correct page ordering (e.g., page 2 before page 10)
img2pdf $(find "$TEMP_DIR" -name "burn-*.png" | sort -V) -o "$OUTPUT_FILE"

# Remove the temporary directory
rm -rf "$TEMP_DIR"