-- ~/.config/hypr/hyprland.lua

-- Lua-Pfad erweitern, damit require() die Module im modules/-Ordner findet
package.path = package.path
    .. ";" .. os.getenv("HOME") .. "/.config/hypr/modules/?.lua"

-- Module laden
require("environment") -- zuerst, weil andere Module ggf. darauf aufbauen
require("input")
require("looks")
require("windows")
require("animations")
require("keybindings")
require("monitors")
