#!/bin/sh

# --- Kitty-Popup starten und darin dein Wallpaper-Picker-Skript ausführen ---
kitty --class fzfwindows \
      --name fzfwindows \
      --override initial_window_width=900 \
      --override initial_window_height=600 \
      /home/azu/.config/hypr/scripts/music_backend.sh
		

