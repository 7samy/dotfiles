-- ~/.config/hypr/looks.lua

-- Da die alte colors-hyprland.conf im hyprlang-Format vorlag und hyprlang
-- seit Hyprland 0.55 nicht mehr unterstützt wird, müssen die Farbvariablen
-- (color0, color10, ...) künftig in Lua definiert werden.
-- Siehe Hinweis unten für die empfohlene Vorgehensweise.
-- ~/.config/hypr/looks.lua

-- pywal-Farben laden (wird bei jedem `wal`-Lauf neu geschrieben)
local wal = dofile(os.getenv("HOME") .. "/.cache/wal/colors.lua")

-- "#rrggbb" -> "rrggbb" für rgba()-Strings
local function rgb(c) return (c:gsub("^#", "")) end

-- Allgemeine Einstellungen
hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 15,
    border_size = 1,

    col = {
      active_border = wal.color5,
      inactive_border = wal.color0,
    },

    resize_on_border = false,
    allow_tearing = false,
  },
})

-- Dekoration (Ecken, Schatten, Blur, Transparenz)
hl.config({
  decoration = {
    rounding = 1,
    rounding_power = 3,

    inactive_opacity = 0.78,
    active_opacity = 0.9,

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(" .. rgb(wal.color0) .. "ee)",
    },

    blur = {
      enabled = true,
      size = 7,
      passes = 2,
      vibrancy = 0.1696,
    },
  },
})

-- Fensterregeln für Transparenz je Anwendung
-- Hinweis: Die alte Syntax `windowrule = opacity 0.95 override 1.0, match:class code-oss`
-- wird nun als Tabelle mit `match` und den Effekt-Parametern geschrieben.
hl.window_rule({
  match = { class = "code-oss" },
  opacity = "0.95 override 1.0",
})
hl.window_rule({
  match = { class = "kitty" },
  opacity = "0.85 override 1.0",
})
hl.window_rule({
  match = { class = "spotify" },
  opacity = "0.95 override 1.0",
})
hl.window_rule({
  match = { class = "gimp" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { class = "discord" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { class = "zen" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { class = "org.quickshell" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { title = "tmux_nvim" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { title = "krita" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { class = "mpv" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { title = "wallpaper-picker" },
  opacity = "1.0 override 1.0",
})
