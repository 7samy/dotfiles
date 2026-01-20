#!/bin/bash

INPUT_FILE="$HOME/.cache/wal/colors.css"
OUTPUT_FILE="$HOME/.config/waybar/theme/waybar_rgba.css"
ALPHA=0.5

# alte Datei löschen
rm -f "$OUTPUT_FILE"

# Hex zu RGBA umwandeln
convert_hex_to_rgba() {
  hex=$(echo "$1" | sed 's/#//' | tr '[:lower:]' '[:upper:]')
  r=$((16#${hex:0:2}))
  g=$((16#${hex:2:2}))
  b=$((16#${hex:4:2}))
  echo "rgba(${r}, ${g}, ${b}, ${ALPHA})"
}

# Farben verarbeiten
grep '^ *--' "$INPUT_FILE" | while read -r line; do
  var=$(echo "$line" | sed -E 's/--([a-zA-Z0-9]+).*/\1/')
  hex=$(echo "$line" | grep -oE '#[A-Fa-f0-9]{6}')
  [ -n "$hex" ] && echo "@define-color $var $(convert_hex_to_rgba $hex);" >> "$OUTPUT_FILE"
done