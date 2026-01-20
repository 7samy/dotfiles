#!/bin/bash

# ~/.config/hypr/scripts/sync_dotfiles.sh

cd ~/dotfiles

rsync -aq ~/.config/hypr/ ~/dotfiles/.config/hypr/
rsync -aq ~/.config/kitty/ ~/dotfiles/.config/kitty/
rsync -aq ~/.config/mpd/ ~/dotfiles/.config/mpd/
rsync -aq ~/.config/neofetch/ ~/dotfiles/.config/neofetch/
rsync -aq ~/.config/nvim/ ~/dotfiles/.config/nvim/
rsync -aq ~/.config/rmpc/ ~/dotfiles/.config/rmpc/
rsync -aq ~/.config/rofi/ ~/dotfiles/.config/rofi/
rsync -aq ~/.config/swayimg/ ~/dotfiles/.config/swayimg/
rsync -aq ~/.config/wal/ ~/dotfiles/.config/wal/
rsync -aq ~/.config/waybar/ ~/dotfiles/.config/waybar/

rsync -aq ~/Pictures/Wallpaper/ ~/dotfiles/wallpaper/

git add .config/ wallpaper/ 2>/dev/null
if ! git diff --cached --quiet; then
    git commit -m "auto: $(date '+%Y-%m-%d %H:%M')" 2>/dev/null
    git push origin main 2>/dev/null
fi
