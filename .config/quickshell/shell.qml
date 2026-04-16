import "./components/"
import "./windows"
import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    GlobalShortcut {
        name: "toggle_launcher"
        onPressed: AppLauncherState.toggle()
    }

    GlobalShortcut {
        name: "toggle_wallpaper"
        onPressed: {
            wallpaperPicker.visible = !wallpaperPicker.visible;
        }
    }

    AppLauncherWindow {
    }

    Wallpaper {
        id: wallpaperPicker

        visible: false
    }

    Variants {
        model: Quickshell.screens.filter((s) => {
            return s.name === "DP-2";
        })

        delegate: Item {
            required property var modelData

            MainBar {
                screen: modelData
            }

            TriggerZone {
                screen: modelData
            }

            WallpaperTriggerzone {
                screen: modelData
            }

            VpnDropDown {
                screen: modelData
            }

            AudioDropdown {
                screen: modelData
            }

        }

    }

}
