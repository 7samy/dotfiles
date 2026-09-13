-- ~/.config/hypr/modules/windows.lua

-- Autostart-Befehle
hl.exec_cmd("/home/azu/.config/hypr/scripts/start.sh")
hl.exec_cmd("/home/azu/.config/hypr/scripts/kitty.sh")
hl.exec_cmd("qs")

-- Workspace-Zuweisungen an Monitore
hl.workspace_rule({ workspace = "1", monitor = "DP-2" })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })
hl.workspace_rule({ workspace = "7", monitor = "DP-2" })
hl.workspace_rule({ workspace = "9", monitor = "DP-2" })

hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
hl.workspace_rule({ workspace = "4", monitor = "DP-3" })
hl.workspace_rule({ workspace = "6", monitor = "DP-1" })
hl.workspace_rule({ workspace = "8", monitor = "DP-1" })
hl.workspace_rule({ workspace = "10", monitor = "DP-1" })

-- Fensterregeln: Workspace-Zuweisungen nach Klasse
hl.window_rule({ match = { class = "kitty" }, workspace = "1" })
hl.window_rule({ match = { class = "zen" }, workspace = "2" })
hl.window_rule({ match = { class = "discord" }, workspace = "4" })
hl.window_rule({ match = { class = "steam" }, workspace = "5" })
hl.window_rule({ match = { class = "com.obsproject.Studio" }, workspace = "6" })
hl.window_rule({ match = { class = "org.openrgb.OpenRGB" }, workspace = "6" })
hl.window_rule({ match = { title = "tmux_nvim" }, workspace = "3" })
hl.window_rule({ match = { class = "nvim-reload" }, workspace = "3" })

-- Fensterregeln: Fullscreen für Spiele
hl.window_rule({ match = { class = "gamescope" }, fullscreen = true })
hl.window_rule({ match = { class = "steam_app_\\d+" }, fullscreen = true })

-- Fensterregeln: Workspace 7 (silent) für Spiele
hl.window_rule({ match = { class = "gamescope" }, workspace = "7 silent" })
hl.window_rule({ match = { class = "steam_app_\\d+" }, workspace = "7 silent" })

-- Fensterregeln: Kein Blur für Spiele
hl.window_rule({ match = { class = "steam_app_\\d+" }, no_blur = true })

-- Workspace 7 ohne Border und Rounding
hl.workspace_rule({ workspace = "7", no_border = true, no_rounding = true })

-- App-Launcher (float, zentriert, feste Größe)
hl.window_rule({
  match = { title = "^(applauncher)$" },
  float = true,
  center = true,
  size = "400 500",
  border_size = 0,
  no_shadow = true,
  rounding = 0,
})

-- Music-Picker (float, zentriert)
hl.window_rule({
  match = { title = "^(music_picker)$" },
  float = true,
  center = true,
})

-- Wallpaper-Picker (float, zentriert, feste Größe, ohne Animation)
hl.window_rule({
  match = { title = "^(wallpaper-picker)$" },
  no_anim = true,
  float = true,
  center = true,
  size = "2560 1480",
  border_size = 0,
  no_shadow = true,
  rounding = 0,
})

-- fzfwindows (float, zentriert)
hl.window_rule({
  match = { class = "^fzfwindows$" },
  float = true,
  size = "900 600",
  center = true,
})

-- swayimg (float, zentriert)
hl.window_rule({
  match = { class = "^swayimg$" },
  float = true,
  size = "1600 1200",
  center = true,
})

-- mpv (float, zentriert)
hl.window_rule({
  match = { class = "^mpv$" },
  float = true,
  size = "1600 1200",
  center = true,
})

-- Maximize-Event für alle Fenster unterdrücken
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Kein Fokus für leere, nicht-floating, nicht-fullscreen, nicht-gepinnte XWayland-Fenster
hl.window_rule({
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = false,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

-- Zen-Browser: opak (benannte Regel)
hl.window_rule({
  name = "zen-opacity",
  match = { class = "^(zen)$" },
  opaque = true,
})
