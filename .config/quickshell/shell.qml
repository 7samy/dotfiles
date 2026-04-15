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
            wallpaperWindow.visible = !wallpaperWindow.visible;
        }
    }

    AppLauncherWindow {
    }

    // HIER kommt das Fenster hin (außerhalb von Variants!)
    Wallpaper {
        id: wallpaperWindow

        visible: false
    }

    Variants {
        // Der Wallpaper-Block ist hier jetzt weg!

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

            VpnDropDown {
                screen: modelData
            }

            AudioDropdown {
                screen: modelData
            }

        }

    }

}
