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
    // ==== Interne Zähler für CPU ====
    property int prevIdle: 0
    property int prevTotal: 0
    property bool firstCpuReading: true
    // ==== Timer ====
    property Timer updateTimer
    // ==== RAM ====
    property Process memProcess
    // ==== CPU-Auslastung ====
    property Process cpuStatProcess
    // ==== CPU-Temperatur ====
    property Process sensorsProcess

    sensorsProcess: Process {
        // Sucht spezifisch nach "Tctl" (dein AMD Sensor), nimmt den Wert und entfernt +, ° und C
        command: ["sh", "-c", "sensors | grep 'Tctl' | head -n 1 | awk '{print $2}' | tr -d '+°C'"]

        stdout: SplitParser {
            onRead: (data) => {
                var out = data.trim();
                if (out !== "")
                    // Optional: Wenn du keine Kommastellen (z.B. 59.6) willst, nutze:
                    // root.cpuTemp = Math.round(parseFloat(out)) + "°C";
                    root.cpuTemp = out + "°C";
                else
                    root.cpuTemp = "--";
            }
        }

    }

    // ==== GPU ====
    property Process gpuProcess
    // ==== Disk ====
    property Process dfProcess

    // ==== Intervall-Steuerung ====
    function update() {
        memProcess.running = false;
        cpuStatProcess.running = false;
        sensorsProcess.running = false;
        gpuProcess.running = false;
        dfProcess.running = false;
        memProcess.running = true;
        cpuStatProcess.running = true;
        sensorsProcess.running = true;
        gpuProcess.running = true;
        dfProcess.running = true;
    }

    Component.onCompleted: {
        root.update();
    }

    updateTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    memProcess: Process {
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo | awk '{print $2}' | paste -sd ' '"]

        stdout: SplitParser {
            onRead: (data) => {
                var out = data.trim();
                if (out === "")
                    return ;

                var parts = out.split(/\s+/);
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

    cpuStatProcess: Process {
        command: ["sh", "-c", "grep '^cpu ' /proc/stat | awk '{print $2, $3, $4, $5, $6, $7, $8, $9}'"]

        stdout: SplitParser {
            onRead: (data) => {
                var out = data.trim();
                if (out === "")
                    return ;

                var parts = out.split(/\s+/);
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

    gpuProcess: Process {
        command: ["sh", "-c", "busy=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | tail -1); temp=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | tail -1); if [ -n \"$busy\" ]; then echo \"$busy $temp\"; else echo '-- --'; fi"]

        stdout: SplitParser {
            onRead: (data) => {
                var out = data.trim();
                if (out === "")
                    return ;

                var parts = out.split(/\s+/);
                if (parts.length >= 1 && parts[0] !== "--")
                    root.gpuUsage = parts[0] + "%";
                else
                    root.gpuUsage = "--";
                if (parts.length >= 2 && parts[1] !== "0" && parts[1] !== "--" && parts[1] !== "") {
                    var tempC = Math.round(parseInt(parts[1], 10) / 1000);
                    root.gpuTemp = tempC + "°C";
                } else {
                    root.gpuTemp = "--";
                }
            }
        }

    }

    dfProcess: Process {
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $2, $3, $5}'"]

        stdout: SplitParser {
            onRead: (data) => {
                var out = data.trim();
                if (out === "")
                    return ;

                var parts = out.split(/\s+/);
                if (parts.length >= 3) {
                    var total = parts[0];
                    var used = parts[1];
                    var percent = parts[2].replace('%', '');
                    root.diskText = used + " / " + total + " (" + percent + "%)";
                    root.diskPercent = parseFloat(percent) || 0;
                }
            }
        }

    }

}
