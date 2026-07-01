#!/usr/bin/env python3
import re
import os

IN_PATH = os.path.expanduser("~/.config/wal/catppuccin-raw.toml")
OUT_PATH = os.path.expanduser("~/.config/wal/templates/theme.toml")

# Catppuccin Frappé Hex -> pywal Platzhalter
COLOR_MAP = {
    "#303446": "{background}",
    "#232634": "{color0}",
    "#292c3c": "{color0}",
    "#414559": "{color0}",
    "#51576d": "{color8}",
    "#626880": "{color8}",
    "#737994": "{color8}",
    "#949cbb": "{color8}",
    "#838ba7": "{color8}",
    "#b5bfe2": "{foreground}",
    "#c6d0f5": "{foreground}",
    "#f2d5cf": "{color7}",
    "#eebebe": "{color7}",
    "#e5c890": "{color3}",
    "#ef9f76": "{color3}",
    "#e78284": "{color1}",
    "#ea999c": "{color1}",
    "#a6d189": "{color2}",
    "#8caaee": "{color4}",
    "#85c1dc": "{color4}",
    "#99d1db": "{color6}",
    "#81c8be": "{color6}",
    "#f4b8e4": "{color5}",
    "#ca9ee6": "{color5}",
    "#ffffff": "{foreground}",
}

with open(IN_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Hex-Farben durch pywal-Platzhalter ersetzen
for hexcode, placeholder in COLOR_MAP.items():
    content = content.replace(hexcode, placeholder)

# 2. Alle pywal-Platzhalter temporär schützen
placeholders_found = sorted(set(re.findall(r'\{[a-zA-Z0-9_]+(?:\.strip)?\}', content)))
for i, p in enumerate(placeholders_found):
    content = content.replace(p, f"@@PH{i}@@")

# 3. Alle übrigen geschweiften Klammern verdoppeln (TOML-Syntax escapen)
content = content.replace("{", "{{").replace("}", "}}")

# 4. Platzhalter zurücksetzen
for i, p in enumerate(placeholders_found):
    content = content.replace(f"@@PH{i}@@", p)

with open(OUT_PATH, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Fertig: {OUT_PATH}")
print(f"{len(placeholders_found)} verschiedene pywal-Platzhalter eingesetzt.")
