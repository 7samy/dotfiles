import "./components/"
import "./windows"
import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    Component.onCompleted: {
        console.log("Quickshell runtime screens:");
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            var s = Quickshell.screens[i];
            console.log("screen", i, s.name, JSON.stringify(s.geometry));
        }
    }

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

    GlobalShortcut {
        name: "toggle_music_picker"
        description: "Toggle Music Picker"
        onPressed: {
            console.log("Music Picker toggled");
            MusicPickerState.toggle();
        }
    }

    AppLauncherWindow {
    }

    Wallpaper {
        id: wallpaperPicker

        visible: false
    }

    MusicPickerWindow {
    }

    Variants {
        model: Quickshell.screens.filter((s) => {
            return s.name === "DP-1";
        })

        delegate: Item {
            required property var modelData

            Component.onCompleted: {
                console.log("Variant delegate created, modelData:", modelData && modelData.name ? modelData.name : modelData);
            }

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
