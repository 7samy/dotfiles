#!/usr/bin/env zsh
# ~/.config/hypr/scripts/hyprlock.zsh

# Lies den aktuellen Wallpaperpfad aus der Pywal-Datei
WALL=$(cat ~/.cache/wal/wal)

# Temporäre Config generieren
TMP_CONF=$(mktemp)

cat > "$TMP_CONF" <<EOF
background {
    path = $WALL
    blur_passes = 2
    blur_size = 5
}

input-field {
    size = 100, 25
    outline_thickness = 0
    dots_size = 0.3
    dots_space = 0.5
    dots_center = true
    inner_color = rgb(FFFFFF)
    font_color = rgb(10, 10, 10)
    hide_input = false
    rounding = -1
    check_color = rgb(255, 97, 97)
    fail_color = rgb(255, 97, 97)
    fail_transition = 300
    position = 0, -20
    halign = center
    valign = center
}

label {
    text = cmd[update:1000] echo "\$TIME"
    color = rgb(FFFFFF)
    font_size = 80
    font_family = Milker
    position = 0, 150
    halign = center
    valign = center
    shadow_passes = 5
    shadow_size = 10
}
EOF

# Hyprlock mit dieser temporären Config starten
hyprlock -c "$TMP_CONF"

# temporäre Datei wieder löschen (nachdem hyprlock beendet ist)
rm "$TMP_CONF"
