pragma Singleton

import QtQuick
import Caelestia
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// The shell's style: compact (the pill and the islands) or full (the classic shell with its
// bar, frame and side panels). Each is its own build of the shell (branches `pill` and `main`):
// switching builds the other one (caelestia-shell-style, as you), installs it (caelestia-admin
// install-shell, asks for the password) and restarts the shell.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-shell-style`
    // "compact" or "full": the shell running now (the compact one has the island's pages)
    readonly property string current: CUtils.fileExists(`${Quickshell.shellDir}/modules/dashboard/mini/MiniOverview.qml`) ? "compact" : "full"
    // "building", "installing" or "" ; the last lines of the build, for the settings
    property string step
    property string log
    property string error

    function switchTo(style: string): void {
        if (step || style === current)
            return;
        error = "";
        log = "";
        if (!CUtils.fileExists(helper)) {
            error = qsTr("the shell's style helper isn't installed (%1)").arg(helper);
            return;
        }
        step = "building";
        buildProc.command = [helper, "build", style];
        buildProc.running = true;
    }

    Process {
        id: buildProc

        stdout: StdioCollector {
            id: buildOut
        }
        stderr: SplitParser {
            onRead: line => {
                const lines = (root.log + "\n" + line).split("\n").filter(l => l.trim());
                root.log = lines.slice(-4).join("\n");
            }
        }
        onExited: code => {
            const file = buildOut.text.trim().split("\n").pop();
            if (code !== 0 || !file) {
                root.step = "";
                root.error = root.log.split("\n").pop() || qsTr("The build failed");
                return;
            }
            root.step = "installing";
            Admin.run("install-shell", [file], qsTr("Install the shell's other style"), (ok, out, cancelled) => {
                root.step = "";
                if (!ok) {
                    root.error = cancelled ? "" : (out.trim().split("\n").pop() || qsTr("Installing failed"));
                    return;
                }
                // The new build takes over: this shell goes, the installed one starts
                Quickshell.execDetached(["setsid", "sh", "-c", "sleep 1; qs -c caelestia kill; sleep 0.5; exec qs -c caelestia -n -d"]);
            });
        }
    }
}
