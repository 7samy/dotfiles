#!/bin/bash

INPUT_FILE="/home/azu/.cache/wal/colors.css"
OUTPUT_FILE="/home/azu/.config/rofi/theme/rofirgba.rasi"
ALPHA=0.4

# ==== ALTE DATEI LÖSCHEN ====
if [ -f "$OUTPUT_FILE" ]; then
  echo "Lösche alte Datei '$OUTPUT_FILE' ..."
  rm -f "$OUTPUT_FILE"
fi

# ==== FUNKTION ZUR UMRECHNUNG ====
convert_hex_to_rgba() {
  local hex=$(echo "$1" | sed 's/#//' | tr '[:lower:]' '[:upper:]')

  # Kurzform (#ABC) erweitern
  if [[ ${#hex} -eq 3 ]]; then
    r=${hex:0:1}${hex:0:1}
    g=${hex:1:1}${hex:1:1}
    b=${hex:2:1}${hex:2:1}
  else
    r=${hex:0:2}
    g=${hex:2:2}
    b=${hex:4:2}
  fi

  # In Dezimal umwandeln
  r_dec=$((16#${r}))
  g_dec=$((16#${g}))
  b_dec=$((16#${b}))
 

  echo "rgba(${r_dec}, ${g_dec}, ${b_dec}, ${ALPHA})"
 
}
 
# ==== DATEI VERARBEITEN ====
echo "Erstelle Rofi-Theme-Datei aus '$INPUT_FILE' → '$OUTPUT_FILE' ..."
echo "*{" >> "$OUTPUT_FILE"
# Wir suchen nur Variablen, die mit -- beginnen
grep '^ *--' "$INPUT_FILE" | while read -r line; do
  # Extrahiere den Namen ohne '--' und die Zahl, z.B. --color1
  var_name=$(echo "$line" | sed -E 's/--([a-zA-Z0-9]+).*/\1/')
  # Extrahiere den HEX-Wert
  hex=$(echo "$line" | grep -oE '#[A-Fa-f0-9]{3,6}')
  
  if [ -n "$hex" ]; then
    rgba=$(convert_hex_to_rgba "$hex")
    echo "$var_name: $rgba;" >> "$OUTPUT_FILE"
  fi
done
echo "}" >> "$OUTPUT_FILE"