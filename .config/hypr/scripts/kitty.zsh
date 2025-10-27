wait_for_window() {
    title="$1"
    while ! hyprctl clients | grep -q "$title"; do
        sleep 0.1
    done
}

kitty --title "Left" &
wait_for_window "Left"

kitty --title "BottomRight" cava &
wait_for_window "BottomRight"

kitty --title "TopRight" rmpc &
wait_for_window "TopRight"


hyprctl dispatch focuswindow "title:Left"
