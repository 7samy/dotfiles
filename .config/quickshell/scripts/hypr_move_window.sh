#!/usr/bin/env bash
# Verschiebt ein Fenster still (ohne den Fokus zu wechseln) auf einen Workspace.
#   Aufruf: hypr_move_window.sh <fensteradresse> <workspace-nr>
#
# Hyprland mit Lua-Config: Die alte Schreibweise
#   hyprctl dispatch movetoworkspacesilent 3,address:0x...
# wird als Lua-Code gelesen und scheitert. Deshalb wird das Fenster per Lua
# anhand der Adresse gesucht und mit hl.dsp.window.move verschoben.
# Klappt das nicht (z.B. noch alte Hyprlang-Config), kommt die alte Schreibweise.

addr="${1#0x}"
addr="${addr,,}"
ws="$2"

# Nur Hex-Adresse und Ziffern zulassen (die Werte landen im Lua-Code)
case "$addr" in '' | *[!0-9a-f]*) exit 1 ;; esac
case "$ws" in '' | *[!0-9]*) exit 1 ;; esac

lua="local w for _, x in ipairs(hl.get_windows()) do if tostring(x.address):lower():gsub(\"^0x\", \"\") == \"$addr\" then w = x end end if not w then return end hl.dispatch(hl.dsp.window.move({ workspace = \"$ws\", follow = false, window = w }))"

out=$(hyprctl eval "$lua" 2>&1)
if printf '%s' "$out" | grep -qiE 'error|invalid|unknown|expected'; then
    hyprctl dispatch "movetoworkspacesilent $ws,address:0x$addr" > /dev/null 2>&1
fi
