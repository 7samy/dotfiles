#!/bin/bash

# Pfade definieren
WAL_COLORS="$HOME/.cache/wal/colors.sh"
YAZI_FLAVOR_DIR="$HOME/.config/yazi/flavors/pywal.yazi"
YAZI_CONFIG="$YAZI_FLAVOR_DIR/flavor.toml"

mkdir -p "$YAZI_FLAVOR_DIR"

if [ -f "$WAL_COLORS" ]; then
    source "$WAL_COLORS"
else
    echo "Pywal colors.sh nicht gefunden!"
    exit 1
fi

# Die neue flavor.toml schreiben
cat <<EOF > "$YAZI_CONFIG"
# vim:fileencoding=utf-8:foldmethod=marker

# : Manager {{{

[mgr]
cwd = { fg = "$color6" }

# Find
find_keyword  = { fg = "$color1", bold = true, italic = true, underline = true }
find_position = { fg = "$color5", bg = "reset", bold = true, italic = true }

# Marker
marker_copied   = { fg = "$color2", bg = "$color2" }
marker_cut      = { fg = "$color3", bg = "$color1" }
marker_marked   = { fg = "$color6", bg = "$color4" }
marker_selected = { fg = "$color3", bg = "$color3" }

# Count
count_copied   = { fg = "$color0", bg = "$color2" }
count_cut      = { fg = "$color0", bg = "$color3" }
count_selected = { fg = "$color0", bg = "$color6" }

# Border
border_symbol = "│"
border_style  = { fg = "$color8" }

# : }}}

# : Tabs {{{

[tabs]
active   = { fg = "$color0", bg = "$color6", bold = true }
inactive = { fg = "$color6", bg = "$color0" }

# : }}}

# : Mode {{{

[mode]
normal_main = { fg = "$color0", bg = "$color6", bold = true }
normal_alt  = { fg = "$color6", bg = "$color0" }

select_main = { fg = "$color0", bg = "$color2", bold = true }
select_alt  = { fg = "$color6", bg = "$color0" }

unset_main = { fg = "$color0", bg = "$color5", bold = true }
unset_alt  = { fg = "$color6", bg = "$color0" }

# : }}}

# : Status bar {{{

[status]
overall = { fg = "$color6" }
sep_left  = { open = "", close = "" }
sep_right = { open = "", close = "" }

# Progress
progress_label = { fg = "$color0", bold = true }
progress_normal = { fg = "$color6", bg = "$color0" }
progress_error = { fg = "$color1", bg = "$color0" }

# Permissions
perm_sep   = { fg = "$color6" }
perm_type  = { fg = "$color2" }
perm_read  = { fg = "$color3" }
perm_write = { fg = "$color1" }
perm_exec  = { fg = "$color5" }

# : }}}

# : Pick {{{

[pick]
border = { fg = "$color6" }
active = { fg = "$color5", bold = true }
inactive = {}

# : }}}

# : Input {{{

[input]
border   = { fg = "$color6" }
title    = {}
value    = {}
selected = { reversed = true }

# : }}}

# : Completion {{{

[cmp]
border = { fg = "$color6" }

# : }}}

# : Tasks {{{

[tasks]
border  = { fg = "$color6" }
title   = {}
hovered = { fg = "$color5", underline = true }

# : }}}

# : Which {{{

[which]
mask            = { bg = "$color8" }
cand            = { fg = "$color2" }
rest            = { fg = "$foreground" }
desc            = { fg = "$color5" }
separator       = "  "
separator_style = { fg = "$color8" }

# : }}}

# : Help {{{

[help]
on      = { fg = "$color2" }
run     = { fg = "$color5" }
hovered = { reversed = true, bold = true }
footer  = { fg = "$color0", bg = "$foreground" }

# : }}}

# : Spotter {{{

[spot]
border   = { fg = "$color6" }
title    = { fg = "$color6" }
tbl_col  = { fg = "$color2" }
tbl_cell = { fg = "$color5", bg = "$color0" }

# : }}}

# : Notify {{{

[notify]
title_info  = { fg = "$color2" }
title_warn  = { fg = "$color1" }
title_error = { fg = "#e0af68" }

# : }}}

# : File-specific styles {{{

[filetype]
rules = [
    # Images
    { mime = "image/*", fg = "$color3" },

    # Media
    { mime = "video/*", fg = "$color1" },
    { mime = "audio/*", fg = "$color1" },

    # Archives
    { mime = "application/zip",             fg = "$color5" },
    { mime = "application/x-tar",            fg = "$color5" },
    { mime = "application/x-bzip*",         fg = "$color5" },
    { mime = "application/x-bzip2",         fg = "$color5" },
    { mime = "application/x-7z-compressed", fg = "$color5" },
    { mime = "application/x-rar",            fg = "$color5" },
    { mime = "application/x-xz",             fg = "$color5" },

    # Documents
    { mime = "application/doc",        fg = "$color2" },
    { mime = "application/epub+zip",   fg = "$color2" },
    { mime = "application/pdf",        fg = "$color2" },
    { mime = "application/rtf",        fg = "$color2" },
    { mime = "application/vnd.*",      fg = "$color2" },

  # Special files
  { mime = "*", is = "orphan", fg = "$color1", bg = "$color0" },
  { mime = "application/*exec*", fg = "$color1" },

    # Fallback
    { url = "*", fg = "$foreground" },
    { url = "*/", fg = "$color6" },
]

# : }}}
EOF

echo "Yazi Flavor 'pywal' wurde erfolgreich mit deiner neuen Struktur aktualisiert!"
