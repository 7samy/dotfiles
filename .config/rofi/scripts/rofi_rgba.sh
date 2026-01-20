#!/bin/bash

INPUT_FILE="/home/azu/.cache/wal/colors.css"
OUTPUT_FILE="/home/azu/.config/rofi/theme/rofi_rgba.rasi"
ALPHA=0.4

# ----- ALTE DATEI LÖSCHEN ----- #
if [ -f "$OUTPUT_FILE" ]; then
  rm -f "$OUTPUT_FILE"
fi

# ----- FUNKTION ZUR UMRECHNUNG ----- #
convert_hex_to_rgba() {
  local hex=$(echo "$1" | sed 's/#//' | tr '[:lower:]' '[:upper:]')

  r=${hex:0:2}
  g=${hex:2:2}
  b=${hex:4:2}

  r_dec=$((16#${r}))
  g_dec=$((16#${g}))
  b_dec=$((16#${b}))
 
  echo "rgba(${r_dec}, ${g_dec}, ${b_dec}, ${ALPHA})"
 
}
 
# ----- DATEI VERARBEITEN ----- #
echo "*{" >> "$OUTPUT_FILE"

grep '^ *--' "$INPUT_FILE" | while read -r line; do

  var_name=$(echo "$line" | sed -E 's/--([a-zA-Z0-9]+).*/\1/')
  hex=$(echo "$line" | grep -oE '#[A-Fa-f0-9]{3,6}')
  
  if [ -n "$hex" ]; then
    rgba=$(convert_hex_to_rgba "$hex")
    echo "$var_name: $rgba;" >> "$OUTPUT_FILE"
  fi
done
echo "}" >> "$OUTPUT_FILE"