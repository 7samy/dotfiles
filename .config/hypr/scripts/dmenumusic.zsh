#!/usr/bin/env zsh

file=$(fd .mp3 ~/Music -p -t f | sort | sed "s|^/home/azu/Music/||" | dmenu -b -i -l 1) || exit 0

# Notification
notify-send "Playing $file"

# Abspielen: Pfad wieder zusammensetzen
mpc insert "$HOME/Music/$file"
mpc next >/dev/null
mpc play >/dev/null
