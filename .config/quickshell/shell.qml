import Quickshell
import Quickshell.Hyprland
import QtQuick
import "./windows"
import "./components/"

ShellRoot {
    // GlobalShortcut aus Quickshell.Hyprland (benötigt Eintrag in hyprland.conf)
    GlobalShortcut {
        name: "toggle_launcher"
        onPressed: AppLauncherState.toggle()
    }

    AppLauncherWindow {}

    Variants {
        model: Quickshell.screens.filter(s => s.name === "DP-2")
        delegate: Item {
            required property var modelData
            MainBar { screen: modelData }
            TriggerZone { screen: modelData }
            VpnDropDown { screen: modelData }
            AudioDropdown { screen: modelData }
        }
    }
}
