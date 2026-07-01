#!/bin/bash
# Watches Pywal-generated Vencord themes and reloads Discord on change

WATCH_FILES=(
    "/home/azu/.config/Vencord/themes/pywall.css"
    "/home/azu/.config/Vencord/themes/zzz_pywal_system24.css"
)

# Reload function (Wayland native)
reload_discord() {
    # Get all Discord windows (class could be 'discord', 'vesktop', 'Discord')
    DISCORD_ADDR=$(hyprctl clients -j | jq -r '.[] | select(.class | test("discord|vesktop"; "i")) | .address' | head -n1)
    if [ -z "$DISCORD_ADDR" ]; then
        return
    fi

    CURRENT=$(hyprctl activewindow -j | jq -r '.address')
    hyprctl dispatch focuswindow address:"$DISCORD_ADDR"
    sleep 0.1
    wtype -M ctrl -k r -m ctrl
    sleep 0.1
    # Return focus
    if [ -n "$CURRENT" ]; then
        hyprctl dispatch focuswindow address:"$CURRENT"
    fi
}

# Watch for changes using inotifywait
inotifywait -m -e close_write "${WATCH_FILES[@]}" | while read -r directory events filename; do
    sleep 0.2   # small delay to let the file finish writing
    reload_discord
done
