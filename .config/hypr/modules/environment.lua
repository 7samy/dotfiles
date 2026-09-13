-- ~/.config/hypr/environment.lua

-- Cursor-Größe
hl.env("XCURSOR_SIZE", "10")
hl.env("HYPRCURSOR_SIZE", "10")

-- XDG_DATA_DIRS erweitern
-- Lua verkettet Strings mit "..". os.getenv liest die bestehende Variable aus.
local existing_data_dirs = os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
hl.env("XDG_DATA_DIRS", os.getenv("HOME") .. "/.local/share:" .. existing_data_dirs)

-- Input-Method-Module für fcitx
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")

-- Hinweis: SDL_IM_MODULE und GLFW_IM_MODULE werden von manchen Apps benötigt
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")
