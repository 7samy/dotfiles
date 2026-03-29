#!/bin/bash

# 1. Auswahl: Video oder Image
mode=$(echo -e "Video\nImage" | fzf --prompt="What are u searching for? " --height=15% --layout=reverse)

if [ -z "$mode" ]; then
    exit 0
fi

# 2. Ordner auswählen
selected_folder=$(find ~ -type d 2>/dev/null | fzf --prompt="Ordner wählen ($mode) > " --height=40%)

if [ -z "$selected_folder" ]; then
    exit 0
fi

selected_folder=$(realpath "$selected_folder")

# 3. Logik basierend auf der Auswahl
if [[ "$mode" == *"Video"* ]]; then
    files=$(find "$selected_folder" -maxdepth 1 -type f \( \
        -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o \
        -iname "*.webm" -o -iname "*.mov" -o -iname "*.flv" -o -iname "*.wmv" \
    \) | sort)

    if [ -n "$files" ]; then
        playlist_file="/tmp/hypr_mpv_playlist.m3u"
        echo "$files" > "$playlist_file"
        hyprctl dispatch exec "mpv --playlist=$playlist_file"
    else
        notify-send "Media Selector" "Keine Videos gefunden!" --icon=dialog-error
    fi

else
    # --- BILDER MODUS ---
    # Create array of image files
    images=()
    while IFS= read -r -d '' file; do
        images+=("$file")
    done < <(find "$selected_folder" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
        -iname "*.webp" -o -iname "*.gif" -o -iname "*.svg" \
    \) -print0 | sort -z)

    if [ ${#images[@]} -gt 0 ]; then
        # Use array expansion with proper quoting
        hyprctl dispatch exec "swayimg -g -- ${images[@]@Q}"
        sleep 0.1
    else
        notify-send "Media Selector" "Keine Bilder gefunden!" --icon=dialog-error
    fi
fi

exit 0
