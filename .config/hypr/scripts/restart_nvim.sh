#!/bin/bash

tmux kill-session -t Nvim 2>/dev/null

pkill -f "[t]itle=tmux_nvim" 2>/dev/null

sleep 0.3

setsid nohup kitty --title="tmux_nvim" tmux new-session -s Nvim nvim >/dev/null 2>&1 &

pkill -x "dein_picker" 2>/dev/null

exit 0
