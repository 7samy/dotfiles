#!/bin/bash

swww-daemon &
sleep 1 
wal -R -n
swww img ~/.cache/wal/wal.png &

wait_for_window() {
    local title="$1"
    local max_attempts=20
    local attempt=1
    
    echo "Waiting for window: $title"
    while [ $attempt -le $max_attempts ]; do
        if hyprctl clients -j | grep -q "\"title\": \"$title\""; then
            echo "Found $title"
            sleep 0.1 
            return 0
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    echo "WARNING: Window '$title' not found"
    return 1
}

kitty --title="Left" &
wait_for_window "Left"

kitty --title="TopRight" -e rmpc &
wait_for_window "TopRight"

hyprctl dispatch focuswindow "title:^TopRight$"
hyprctl dispatch movewindow r

hyprctl dispatch focuswindow "title:^TopRight$"
sleep 0.2
kitty --title="BottomRight" -e cava &
wait_for_window "BottomRight"

hyprctl dispatch focuswindow "title:^BottomRight$"
hyprctl dispatch movewindow d

hyprctl dispatch focuswindow "title:^Left$"

kitty --title="tmux_nvim" tmux new-session -A -s Nvim nvim &



# APPLICATIONS #

discord &
steam & 
zen-browser & 
openrgb &



# AUDIO #

systemctl --user enable --now mpd.service
sleep 2  # Give MPD time to start

while ! mpc status &>/dev/null; do
    echo "Waiting for MPD to start..."
    sleep 1
done

mpc listall | mpc add
echo "Added $(mpc playlist | wc -l) songs to queue"

ln -sf ~/.cache/wal/colors-kitty.conf ~/.config/kitty/themes/current-theme.conf
killall -SIGUSR1 kitty
