#!/bin/bash
set -euo pipefail

DIR="$HOME/Music"

selected_file=$(find "$DIR" -type f | sort -V | fzf --reverse) || exit 0
relative_file="${selected_file#$DIR/}"

mpc clear
mpc listall | mpc add

song_position=$(mpc playlist -f "%file%" | grep -nF "$relative_file" | cut -d: -f1 | head -n 1)


if [ -n "$song_position" ]; then
    mpc play "$song_position"
    mpc seek 0
else
    echo "Fehler: Konnte den Song nicht in der Playlist finden."
fi


exit 0
