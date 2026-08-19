import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    // ==== Properties ====
    property real ramPercent: 0
    property string ramText: "--"
    property real cpuPercent: 0
    property string cpuTemp: "--"
    property string gpuUsage: "--"
    property string gpuTemp: "--"
    property real diskPercent: 0
    property string diskText: "--"
    // ==== Interne Zähler für CPU-Berechnung ====
    property int prevIdle: 0
    property int prevTotal: 0
    property bool firstCpuReading: true
    // ==== Aktualisierungs-Timer ====
    property Timer updateTimer

    updateTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    // ==== RAM ====
    property Process memProcess

    memProcess: Process {
        id: memProc

        running: false
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo | awk '{print $2}' | paste -sd ' '"]
        onExited: {
            if (memProc.exitCode === 0 && memProc.stdout !== null && memProc.stdout.trim() !== "") {
                var parts = memProc.stdout.trim().split(/\s+/);
                if (parts.length >= 2) {
                    var total = parseInt(parts[0], 10);
                    var available = parseInt(parts[1], 10);
                    var used = total - available;
                    root.ramPercent = Math.round((used / total) * 100);
                    root.ramText = Math.round(used / 1024) + "M / " + Math.round(total / 1024) + "M (" + root.ramPercent + "%)";
                }
            }
        }
    }

    // ==== CPU-Auslastung ====
    property Process cpuStatProcess

    cpuStatProcess: Process {
        id: cpuProc

        running: false
        command: ["sh", "-c", "grep '^cpu ' /proc/stat | awk '{print $2, $3, $4, $5, $6, $7, $8, $9}'"]
        onExited: {
            if (cpuProc.exitCode === 0 && cpuProc.stdout !== null && cpuProc.stdout.trim() !== "") {
                var parts = cpuProc.stdout.trim().split(/\s+/);
                if (parts.length >= 8) {
                    var user = parseInt(parts[0], 10);
                    var nice = parseInt(parts[1], 10);
                    var system = parseInt(parts[2], 10);
                    var idle = parseInt(parts[3], 10);
                    var iowait = parseInt(parts[4], 10);
                    var irq = parseInt(parts[5], 10);
                    var softirq = parseInt(parts[6], 10);
                    var steal = parseInt(parts[7], 10) || 0;
                    var total = user + nice + system + idle + iowait + irq + softirq + steal;
                    var totalIdle = idle + iowait;
                    if (!root.firstCpuReading) {
                        var diffIdle = totalIdle - root.prevIdle;
                        var diffTotal = total - root.prevTotal;
                        if (diffTotal > 0)
                            root.cpuPercent = Math.max(0, Math.min(100, Math.round((1 - diffIdle / diffTotal) * 100)));

                    } else {
                        root.firstCpuReading = false;
                    }
                    root.prevIdle = totalIdle;
                    root.prevTotal = total;
                }
            }
        }
    }

    // ==== CPU-Temperatur ====
    property Process sensorsProcess

    sensorsProcess: Process {
        id: sensorsProc

        running: false
        command: ["sh", "-c", "sensors | grep -E 'Package id 0|Tctl|Tccd1' | head -1 | awk -F: '{print $2}' | sed 's/^[ \t]*//' | sed 's/[+°C].*//'"]
        onExited: {
            if (sensorsProc.exitCode === 0 && sensorsProc.stdout !== null && sensorsProc.stdout.trim() !== "")
                root.cpuTemp = sensorsProc.stdout.trim() + "°C";
            else
                root.cpuTemp = "--";
        }
    }

    // ==== GPU (AMD) ====
    property Process gpuProcess

    gpuProcess: Process {
        id: gpuProc

        running: false
        command: ["sh", "-c", "busy=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); temp=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); if [ -n \"$busy\" ]; then echo \"$busy $temp\"; else echo '-- --'; fi"]
        onExited: {
            if (gpuProc.exitCode === 0 && gpuProc.stdout !== null && gpuProc.stdout.trim() !== "") {
                var parts = gpuProc.stdout.trim().split(/\s+/);
                if (parts.length >= 1 && parts[0] !== "--")
                    root.gpuUsage = parts[0] + "%";
                else
                    root.gpuUsage = "--";
                if (parts.length >= 2 && parts[1] !== "0" && parts[1] !== "") {
                    var tempC = Math.round(parseInt(parts[1], 10) / 1000);
                    root.gpuTemp = tempC + "°C";
                } else {
                    root.gpuTemp = "--";
                }
            } else {
                root.gpuUsage = "--";
                root.gpuTemp = "--";
            }
        }
    }

    // ==== Speicherplatz ====
    property Process dfProcess

    dfProcess: Process {
        id: dfProc

        running: false
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $2, $3, $5}'"]
        onExited: {
            if (dfProc.exitCode === 0 && dfProc.stdout !== null && dfProc.stdout.trim() !== "") {
                var parts = dfProc.stdout.trim().split(/\s+/);
                if (parts.length >= 3) {
                    var total = parts[0];
                    var used = parts[1];
                    var percent = parts[2].replace('%', '');
                    root.diskText = used + " / " + total + " (" + percent + "%)";
                    root.diskPercent = parseFloat(percent) || 0;
                }
            } else {
                root.diskText = "--";
                root.diskPercent = 0;
            }
        }
    }

    // ==== Aktualisierungsfunktion ====
    function update() {
        memProcess.running = true;
        cpuStatProcess.running = true;
        sensorsProcess.running = true;
        gpuProcess.running = true;
        dfProcess.running = true;
    }

}
