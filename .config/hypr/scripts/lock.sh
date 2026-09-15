#!/bin/bash
# Liest das aktuelle pywal-Wallpaper und verlinkt es fest,
# damit hyprlock es laden kann.

WALL=$(cat ~/.cache/wal/wal)

# Symlink auf das aktuelle Wallpaper setzen
ln -sf "$WALL" /tmp/hyprlock_wallpaper.png

# Hyprlock starten
exec hyprlock
