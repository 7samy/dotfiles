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

    // OPTIONAL: Ein Shortcut für Ollama
    GlobalShortcut {
        name: "toggle_ollama"
        onPressed: OllamaState.toggle()
    }

    AppLauncherWindow {
    }

    Wallpaper {
        id: wallpaperPicker

        visible: false
    }

    Variants {
        // OllamaTriggerZone {
        //    screen: modelData
        //}
        // NEU: HIER KOMMT DEINE OLLAMA SIDEBAR HIN
        //OllamaSidebar {
        //   screen: modelData
        // }

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
