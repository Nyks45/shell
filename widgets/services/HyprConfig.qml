pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The monitors Hyprland knows, connected or not (`hyprctl monitors all`): the widgets use it to
// size a screen that isn't there right now. Only a list: the shell's own settings set up
// Hyprland (this used to also re-apply the widgets' old input, blur, window, border and monitor
// settings on every config reload, overriding the shell's).
Singleton {
    id: root

    property var monitors: []

    function refresh() {
        list.running = true;
    }

    Process {
        id: list
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name: m.name,
                        description: m.description,
                        disabled: m.disabled,
                        scale: m.scale,
                        mode: `${m.width}x${m.height}@${Math.round(m.refreshRate)}`
                    }));
                } catch (e) {
                    console.warn("HyprConfig: could not read monitors", e);
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "monitoradded" || event.name === "monitorremoved")
                refreshTimer.restart();
        }
    }

    Component.onCompleted: refresh()
}
