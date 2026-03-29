#!/bin/bash

# Simply launch kitty running your script. 
# Hyprland automatically passes the environment to Kitty.

kitty --class fzfwindows \
      --name fzfwindows \
      --override initial_window_width=900 \
      --override initial_window_height=600 \
      bash -c "/home/azu/.config/hypr/scripts/viewer_backend.sh"
