import QtQuick
import Quickshell
import Quickshell.Hyprland

Text {
    height: parent.height
    width: 200
    text: {
        var toplevels = Hyprland.toplevels.values
        for (var i = 0; i < toplevels.length; i++) {
            if (toplevels[i].activated) {
                var obj = toplevels[i].lastIpcObject
                return obj?.initialTitle ?? toplevels[i].title
            }
        }
        return ""
    }
    color: WalColors.color2
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1
}
