pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Installed font families, for the settings app's font pickers.
Singleton {
    id: root

    // Every family Qt knows, hidden ones (".Foo") left out
    readonly property list<string> families: Qt.fontFamilies().filter(f => !f.startsWith("."))
    // Fixed-width families (fontconfig: spacing=mono)
    property list<string> monoFamilies: []

    function reload(): void {
        monoProc.running = true;
    }

    Process {
        id: monoProc

        running: true
        command: ["sh", "-c", "fc-list :spacing=mono family; fc-list :spacing=dual family"]
        stdout: StdioCollector {
            onStreamFinished: {
                const set = new Set();
                for (const line of text.split("\n")) {
                    const name = line.split(",")[0].trim();
                    if (name)
                        set.add(name);
                }
                root.monoFamilies = [...set].sort((a, b) => a.localeCompare(b));
            }
        }
    }
}
