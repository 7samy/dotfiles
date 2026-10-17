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
        AppLauncherState.loadApps();
        MusicPickerState.loadSongs();
        WallpaperPickerState.loadWallpapers();
        ClipboardState.refresh();
    }

    GlobalShortcut {
        name: "toggle_clipboard"
        onPressed: ClipboardState.toggle()
    }

    GlobalShortcut {
        name: "toggle_japanese_audio"
        onPressed: JapaneseAudioState.toggle()
    }

    GlobalShortcut {
        name: "toggle_launcher"
        onPressed: AppLauncherState.toggle()
    }

    GlobalShortcut {
        name: "toggle_wallpaper"
        onPressed: WallpaperPickerState.toggle()
    }

    GlobalShortcut {
        name: "toggle_music_picker"
        description: "Toggle Music Picker"
        onPressed: {
            console.log("Music Picker toggled");
            MusicPickerState.toggle();
        }
    }

    PickerWindow {
    }

    WorkspaceOverview {
    }

    Variants {
        model: Quickshell.screens.filter((s) => {
            return s.name === "DP-2";
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

            VolumeTriggerZone {
                screen: modelData
            }

            VpnDropDown {
                screen: modelData
            }

            AudioDropdown {
                screen: modelData
            }

            VpnPickerWindow {
                screen: modelData
            }

            VolumeSliderPopup {
                screen: modelData
            }

            PowerMenu {
            }

            StatsDropdown {
                screen: modelData
            }

        }

    }

}
