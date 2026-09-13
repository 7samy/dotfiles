local mainMod = "SUPER"

-- Terminal
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("kitty"))

-- Fenster schließen
hl.bind(mainMod .. " + C", hl.dsp.window.close())

-- Floating-Modus umschalten
hl.bind(mainMod .. " + B", hl.dsp.window.float({ action = "toggle" }))

-- Pseudo-Tiling umschalten
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Quickshell neu starten
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("qs"))

-- Quickshell-Module umschalten
hl.bind(mainMod .. " + M", hl.dsp.global("quickshell:toggle_music_picker"))
hl.bind(mainMod .. " + G", hl.dsp.global("quickshell:toggle_wallpaper"))
hl.bind(mainMod .. " + SPACE", hl.dsp.global("quickshell:toggle_launcher"))

-- Benutzerdefinierte Skripte ausführen
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("/home/azu/.config/hypr/scripts/filemanager.sh"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("/home/azu/.config/hypr/scripts/screenshot.sh"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("/home/azu/.config/hypr/scripts/nvim.sh"))

-- Vial (AppImage) starten
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("./Vial-v0.7.1-x86_64.AppImage --no-sandbox"))

-- Fensterfokus mit Vim-Tasten (H, J, K, L)
hl.bind(mainMod .. " + H", hl.dsp.window.move({ direction = "l" })) -- movefocus l
hl.bind(mainMod .. " + L", hl.dsp.window.move({ direction = "r" })) -- movefocus r
hl.bind(mainMod .. " + K", hl.dsp.window.move({ direction = "u" })) -- movefocus u
hl.bind(mainMod .. " + J", hl.dsp.window.move({ direction = "d" })) -- movefocus d

-- Arbeitsbereiche 1-10 wechseln
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Aktives Fenster in Arbeitsbereich 1-10 verschieben
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Maus-Bindings: Fenster verschieben und skalieren
-- 272 ist LMB (Linksklick), 273 ist RMB (Rechtsklick)
-- 'mouse = true' aktiviert den Maus-Bind-Modus[reference:0]
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media-Tasten (funktionieren auch bei gesperrtem Bildschirm)[reference:1]
-- 'locked = true' stellt sicher, dass die Bindung auch bei aktivem Lockscreen funktioniert.
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
