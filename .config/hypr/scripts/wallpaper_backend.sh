#!/bin/sh

DIR="/home/azu/Pictures/Wallpaper"

# --- fzf mit chafa Preview ---
selected_file=$(find "$DIR" -type f | sort -V | fzf --reverse \
    --preview="chafa --size=\"\$FZF_PREVIEW_COLUMNS\"x\"\$FZF_PREVIEW_LINES\" {}")

# Falls keine Datei ausgewählt wurde, beende das Skript
[ -z "$selected_file" ] && exit 0

# Setze Wallpaper und Farben
wal -n -i "$selected_file"
wpg -s "$selected_file"
swww img "$selected_file" --transition-type fade --transition-step 10

pkill qs
sleep 1
qs &

# ----- FOLGENDE SKRIPTE AUSFÜHREN ----- #
/home/azu/.config/rofi/scripts/rofi_rgba.sh
/home/azu/.config/hypr/scripts/restart_nvim.sh
/home/azu/.config/hypr/scripts/yazi_wal.sh
