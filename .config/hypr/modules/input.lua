-- ~/.config/hypr/input.lua

-- Globale Input-Einstellungen
hl.config({
  input = {
    kb_layout = "de",
    kb_options = "caps:escape",
    accel_profile = "flat",
    follow_mouse = 1,
    sensitivity = 0.3,
    force_no_accel = true,
  },
})

-- Gerätespezifische Einstellungen für deine Maus
-- Hinweis: force_no_accel und follow_mouse sind hier NICHT erlaubt,
--          da sie nur global gesetzt werden können.[reference:2]
hl.device({
  name = "epic-mouse-v1",
  sensitivity = -0.5,
})

hl.device({
  name = "huion-huion-tablet_gt-156-v2-pen",
  output = "HDMI-A-1",
})
