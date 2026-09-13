-- ~/.config/hypr/looks.lua

-- Da die alte colors-hyprland.conf im hyprlang-Format vorlag und hyprlang
-- seit Hyprland 0.55 nicht mehr unterstützt wird, müssen die Farbvariablen
-- (color0, color10, ...) künftig in Lua definiert werden.
-- Siehe Hinweis unten für die empfohlene Vorgehensweise.

-- Allgemeine Einstellungen
hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 15,
    border_size = 1,

    col = {
      active_border = "#ffffff", -- siehe Hinweis unten
      inactive_border = "#111111",
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
      color = "rgba(1a1a1aee)",
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
  match = { class = "mpv" },
  opacity = "1.0 override 1.0",
})
hl.window_rule({
  match = { title = "wallpaper-picker" },
  opacity = "1.0 override 1.0",
})
