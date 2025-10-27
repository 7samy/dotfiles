#!/bin/zsh

# Führe wal -R zweimal aus
sleep 1
wal -R -n
swww img ~/.cache/wal/wal.png --transition-type fade --transition-step 10

ln -sf ~/.cache/wal/colors-kitty.conf ~/.config/kitty/themes/current-theme.conf
