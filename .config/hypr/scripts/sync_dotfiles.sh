#!/bin/bash

# ~/.config/hypr/scripts/sync_dotfiles.sh

cd ~/dotfiles

rsync -aq --delete ~/.config/hypr/ ~/dotfiles/.config/hypr/
rsync -aq --delete ~/.config/kitty/ ~/dotfiles/.config/kitty/
rsync -aq --delete ~/.config/mpd/ ~/dotfiles/.config/mpd/
rsync -aq --delete ~/.config/neofetch/ ~/dotfiles/.config/neofetch/
rsync -aq --delete ~/.config/nvim/ ~/dotfiles/.config/nvim/
rsync -aq --delete ~/.config/rmpc/ ~/dotfiles/.config/rmpc/
rsync -aq --delete ~/.config/swayimg/ ~/dotfiles/.config/swayimg/
rsync -aq --delete ~/.config/wal/ ~/dotfiles/.config/wal/
rsync -aq --delete ~/.config/waybar/ ~/dotfiles/.config/waybar/

rsync -aq --delete ~/Pictures/Wallpaper/ ~/dotfiles/wallpaper/

git add .config/ wallpaper/ 2>/dev/null
if ! git diff --cached --quiet; then
    git commit -m "auto: $(date '+%Y-%m-%d %H:%M')" 2>/dev/null
    git push origin main 2>/dev/null
fi
