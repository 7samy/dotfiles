#!/bin/bash
path="$1"

swww img "$path" --transition-type simple --transition-duration 0.8 --transition-fps 60
wal -n -i "$path"
wpg -s "$path"
killall -SIGUSR1 nvim 2>/dev/null

# --- Spicetify / Spotify ---
spicetify apply --no-restart
pkill -f /opt/spotify/spotify
sleep 1
setsid spotify </dev/null >/dev/null 2>&1 &
disown

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
