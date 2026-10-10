#!/bin/bash
# Generiert ein Obsidian-Snippet aus den aktuellen wal-Farben

VAULT="$1"
if [ -z "$VAULT" ]; then
    echo "Usage: $0 /pfad/zu/deinem/vault"
    exit 1
fi

SNIPPET_DIR="$VAULT/.obsidian/snippets"
SNIPPET="$SNIPPET_DIR/wal-colors.css"
mkdir -p "$SNIPPET_DIR"

python3 - "$SNIPPET" << 'PYEOF'
import json, sys

snippet_path = sys.argv[1]

with open('/home/azu/.cache/wal/colors.json') as f:
    wal = json.load(f)

c = wal['colors']
s = wal['special']

def rgb(h):
    h = h.lstrip('#')
    return f"{int(h[0:2],16)}, {int(h[2:4],16)}, {int(h[4:6],16)}"

def lerp(h1, h2, t):
    a, b = h1.lstrip('#'), h2.lstrip('#')
    return '#' + ''.join(
        f"{int(int(a[i:i+2],16) + (int(b[i:i+2],16)-int(a[i:i+2],16))*t):02x}"
        for i in (0, 2, 4)
    )

def darker(h, f):
    h = h.lstrip('#')
    return '#' + ''.join(f"{int(int(h[i:i+2],16)*f):02x}" for i in (0, 2, 4))

bg = s['background']
fg = s['foreground']

# Akzentfarben – hier bestimmst du, welcher wal-Slot was wird
accents = {
    'rosewater': c['color7'],
    'flamingo':  c['color15'],
    'pink':      c['color13'],
    'mauve':     c['color5'],
    'red':       c['color1'],
    'maroon':    c['color9'],
    'peach':     c['color3'],
    'yellow':    c['color11'],
    'green':     c['color2'],
    'teal':      c['color6'],
    'sky':       c['color14'],
    'sapphire':  c['color12'],
    'blue':      c['color4'],
    'lavender':  c['color13'],
}

# Neutrale Töne – interpoliert zwischen fg und bg
neutrals = {
    'text':      fg,
    'subtext1':  lerp(fg, bg, 0.15),
    'subtext0':  lerp(fg, bg, 0.30),
    'overlay2':  lerp(fg, bg, 0.45),
    'overlay1':  lerp(fg, bg, 0.55),
    'overlay0':  lerp(fg, bg, 0.65),
    'surface2':  lerp(fg, bg, 0.78),
    'surface1':  lerp(fg, bg, 0.88),
    'surface0':  lerp(fg, bg, 0.94),
    'base':      bg,
    'mantle':    darker(bg, 0.85),
    'crust':     darker(bg, 0.70),
}

with open(snippet_path, 'w') as out:
    out.write("/* Auto-generated from pywal – nicht von Hand editieren */\n")
    out.write("/* Regenerieren: ~/.config/wal/gen-obsidian-wal.sh /pfad/zum/vault */\n\n")
    out.write(".theme-dark, .theme-light {\n")
    for name, hexv in accents.items():
        out.write(f"  --ctp-{name}: {rgb(hexv)} !important;\n")
    for name, hexv in neutrals.items():
        out.write(f"  --ctp-{name}: {rgb(hexv)} !important;\n")
    out.write("}\n")

print(f"Snippet geschrieben: {snippet_path}")
PYEOF
