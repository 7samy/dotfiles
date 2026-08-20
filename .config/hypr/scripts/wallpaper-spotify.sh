#!/bin/bash
path="$1"

swww img "$path" --transition-type simple --transition-duration 0.8 --transition-fps 60
wal -n -i "$path"
wpg -s "$path"
killall -SIGUSR1 nvim 2>/dev/null

# --- Discord automatisch neu laden ---
if pgrep -f "discord" > /dev/null; then
    if command -v xdotool > /dev/null; then
        # Versuche über xdotool (XWayland)
        xdotool search --class "discord" key --window %@ ctrl+r 2>/dev/null || true
    elif command -v hyprctl > /dev/null && command -v wtype > /dev/null && command -v jq > /dev/null; then
        # Fallback für natives Wayland (Hyprland)
        current=$(hyprctl activewindow -j | jq -r '.address')
        discord_addr=$(hyprctl clients -j | jq -r '.[] | select(.class == "discord") | .address')
        if [ -n "$discord_addr" ]; then
            hyprctl dispatch focuswindow address:$discord_addr
            sleep 0.1
            wtype -M ctrl -k r -m ctrl
            sleep 0.1
            [ -n "$current" ] && hyprctl dispatch focuswindow address:$current
        fi
    else
        echo "Weder xdotool noch wtype+hyprctl verfügbar – Discord wurde nicht neu geladen." >&2
    fi
fi

# --- Spicetify / Spotify ---
spicetify apply --no-restart
pkill -f /opt/spotify/spotify
sleep 1

# --- Zen Browser ---
ZEN_PREFS="/home/azu/.config/zen/s3945da8.Default (release)/prefs.js"
NEW_ZEN_COLOR=$(cat ~/.cache/wal/colors-zen.txt)

if pgrep -f "zen-bin" > /dev/null; then
    WAS_RUNNING=1
    pkill -f "zen-bin"
    sleep 1
else
    WAS_RUNNING=0
fi

sed -i '/mod\.sameerasw\.zen_transparency_color/d' "$ZEN_PREFS"
echo "user_pref(\"mod.sameerasw.zen_transparency_color\", \"$NEW_ZEN_COLOR\");" >> "$ZEN_PREFS"

if [ "$WAS_RUNNING" = "1" ]; then
    setsid /opt/zen-browser-bin/zen-bin </dev/null >/dev/null 2>&1 &
    disown
fi
