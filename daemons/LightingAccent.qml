pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// Keeps RGB lighting synced to the active colour scheme accent even after
// Settings > Lighting closes (mirrors caelestia-devices lighting-set).
Scope {
    id: root

    property bool followAccent
    property string lastApplied
    property bool initialized

    readonly property string configPath: `${Paths.config}/lighting.json`
    readonly property string helper: `${Paths.libdir}/caelestia-devices`
    readonly property string accent: String(Colours.palette.m3primary).replace(/^#/, "").slice(-6)

    function applyAccent(): void {
        if (!followAccent || !accent || accent === lastApplied)
            return;
        lastApplied = accent;
        applyProc.running = false;
        applyProc.command = ["sh", "-c", 'printf "%s" "$2" | "$1" lighting-set', "sh", helper, JSON.stringify({
            device: "*",
            color: accent
        })];
        applyProc.running = true;
    }

    Connections {
        function onM3primaryChanged(): void {
            if (root.followAccent)
                accentTimer.restart();
        }

        target: Colours.palette
    }

    Timer {
        id: accentTimer

        interval: 1500
        onTriggered: root.applyAccent()
    }

    Process {
        id: applyProc
    }

    FileView {
        id: configFile

        path: root.configPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const wasFollowing = root.followAccent;
            try {
                const data = JSON.parse(text());
                root.followAccent = !!data.followAccent;
            } catch (e) {
                root.followAccent = false;
            }
            if (!root.initialized || (!wasFollowing && root.followAccent)) {
                root.initialized = true;
                root.lastApplied = root.accent;
            }
        }
        onLoadFailed: {
            root.followAccent = false;
            if (!root.initialized) {
                root.initialized = true;
                root.lastApplied = root.accent;
            }
        }
    }
}
