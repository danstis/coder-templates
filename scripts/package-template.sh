#!/usr/bin/env bash

set -euo pipefail

TEMPLATE_DIR="$1"
OUTPUT_DIR="${2:-dist}"

if [ -z "$TEMPLATE_DIR" ]; then
  echo "Usage: $0 <template-dir> [output-dir]"
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Directory $TEMPLATE_DIR does not exist"
  exit 1
fi

TEMPLATE_NAME=$(basename "$TEMPLATE_DIR")
mkdir -p "$OUTPUT_DIR"

# Get absolute path of output dir to ensure zip command finds it
# regardless of directory change
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

echo "Packaging $TEMPLATE_NAME..."

# Zip contents:
# -r: recursive
# -q: quiet
# -x: exclude patterns (terraform state, hidden files)
(cd "$TEMPLATE_DIR" && zip -r -q "$OUTPUT_DIR_ABS/$TEMPLATE_NAME.zip" . -x "*.terraform*" "*.git*" "*.tfstate*")

echo "Created $OUTPUT_DIR/$TEMPLATE_NAME.zip"
