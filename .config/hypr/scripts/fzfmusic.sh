#!/bin/sh

DIR="$HOME/Music"
selected_file=$(find "$DIR" -type f | sort -V | fzf --reverse)
[ -z "$selected_file" ] && exit 0

relative_file="${selected_file#$DIR/}"

echo "DEBUG: selected_file = $selected_file"
echo "DEBUG: relative_file = $relative_file"

# Clear, add the song, get its position, then play
rmpc clear
rmpc add "$relative_file"
song_position=$(rmpc playlist | grep -n "$relative_file" | cut -d: -f1)
mpc listall | mpc add
# Play the song at the found position (default to 0 if not found)
rmpc play "${song_position:-0}"
rmpc seek 0

echo "Starte: $selected_file"
