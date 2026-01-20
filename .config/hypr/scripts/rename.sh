!#/bin/bash

#!/bin/bash

kitty --class fzfwindows \
      --name fzfwindows \
      --override initial_window_width=900 \
      --override initial_window_height=600 \
      bash -c "/home/azu/.config/hypr/scripts/organize_media.sh"
