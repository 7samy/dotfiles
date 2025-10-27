#!/usr/bin/env zsh

# Finde alle PNGs (rekursiv), speichere in Array
files=($(fd -t f -e png -i . ~/Pictures/Wallpaper | sort -V))

# Zeige nur Dateinamen in dmenu
file=$(printf "%s\n" "${files[@]##*/}" | dmenu -b -i -l 1) || exit 0

# Suche den absoluten Pfad der ausgewählten Datei
selected_file=""
for f in "${files[@]}"; do
    if [[ "${f##*/}" == "$file" ]]; then
        selected_file="$f"
        break
    fi
done

# Wallpaper anwenden
wal -n -i "$selected_file"
swww img "$selected_file" --transition-type fade --transition-step 10
