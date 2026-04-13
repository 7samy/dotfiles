pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property var windowList: []
    property var windowByAddress: ({})

    function biggestWindowForWorkspace(workspaceId) {
        const windows = root.windowList.filter(w => w.workspace.id == workspaceId)
        return windows.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0)
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0)
            return winArea > maxArea ? win : maxWin
        }, null)
    }

    function updateWindowList() {
        getClients.running = true
    }

    Component.onCompleted: updateWindowList()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            root.updateWindowList()
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.windowList = JSON.parse(text)
                let tmp = {}
                for (var i = 0; i < root.windowList.length; i++) {
                    tmp[root.windowList[i].address] = root.windowList[i]
                }
                root.windowByAddress = tmp
            }
        }
    }
}
