#!/bin/bash

WAL_COLORS="$HOME/.cache/wal/colors.sh"
YAZI_FLAVOR_DIR="$HOME/.config/yazi/flavors/pywal.yazi"
YAZI_CONFIG="$YAZI_FLAVOR_DIR/flavor.toml"

mkdir -p "$YAZI_FLAVOR_DIR"

if [ -f "$WAL_COLORS" ]; then
    source "$WAL_COLORS"
else
    echo "Pywal colors nicht gefunden!"
    exit 1
fi

cat <<EOF > "$YAZI_CONFIG"
[flavor]
name = "pywal"

[icon]
prepend_rules = [
  # Ordner müssen IMMER als erstes kommen
  { name = "*/", fg = "$color4" },

  # MIME-Typen (das greift oft stärker als Dateiendungen)
  { mime = "image/*", fg = "$color3" },
  { mime = "video/*", fg = "$color1" },
  { mime = "audio/*", fg = "$color1" },
  { mime = "application/pdf", fg = "$color1" },
  { mime = "application/x-tar", fg = "$color5" },
  { mime = "application/zip", fg = "$color5" },
  { mime = "application/javascript", fg = "$color3" },

  # Spezifische Namen/Endungen als Backup
  { name = "Downloads/", fg = "$color2" },
  { name = "Videos/",    fg = "$color1" },
  { name = "Pictures/",  fg = "$color5" },
  { name = "*.py",       fg = "$color11" },
  { name = "*.md",       fg = "$color6" },
  { name = "*.lua",      fg = "$color4" },

  # Der Catch-all für alles andere
  { name = "*",          fg = "$foreground" }
]
EOF

echo "Yazi: Force-Icon-Flavor generiert!"
