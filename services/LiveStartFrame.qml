pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Login order, like Windows: the shell first, then the live wallpaper. The
// shell starts the renderer itself once it has drawn (not Hyprland at login,
// where both loaded at once and competed for the GPU). The renderer needs a
// few seconds to load its scene: until its first frame the background shows
// the last frame it saved (frame-<id>.png, from its --screenshot); "ready"
// turns true when it writes a new one (or was running already, or after a
// while), and the background fades it out.
Singleton {
    id: root

    readonly property string state: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`
    // The wallpaper set for all screens (a playlist: the frame the service knows)
    readonly property string current: LiveWallpaper.current
    readonly property string frame: !current ? "" : current.startsWith("playlist:") ? LiveWallpaper.currentFrame : `${state}/live-wallpaper/frame-${current.split("/").pop()}.png`
    // When the shell started (a frame written after it is the renderer's first)
    readonly property real startedAt: Date.now() / 1000
    property bool ready
    property bool checked
    property bool wasRunning
    property bool started

    // Shown while the renderer loads
    readonly property bool showing: !!frame && checked && !ready

    // This session's renderer already running (a shell restart): nothing to
    // cover. Its pid file, as the script keeps it (per state folder: a test
    // shell with its own XDG_STATE_HOME sees only its own)
    Process {
        running: true
        command: ["sh", "-c", `p=$(cat "${root.state}/live-wallpaper/pid" 2>/dev/null) && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ]`]
        onExited: code => {
            if (code === 0) {
                root.ready = true;
                root.wasRunning = true;
            }
            root.checked = true;
        }
    }

    // Start the renderer a moment after the shell has drawn (once per login:
    // not when it was running already, e.g. after a shell restart)
    Timer {
        running: root.checked && !root.wasRunning && !root.started && !!root.current
        interval: 600
        onTriggered: {
            root.started = true;
            // through PATH (~/.local/bin links the shell's script; the dev
            // sandbox's stub catches it there)
            Quickshell.execDetached(["live-wallpaper", "start"]);
        }
    }

    // A new frame from the renderer: it's drawing
    Timer {
        running: root.showing
        repeat: true
        interval: 300
        onTriggered: if (!statProc.running)
            statProc.running = true
    }

    Process {
        id: statProc

        command: ["stat", "-c", "%Y", root.frame]
        stdout: StdioCollector {
            onStreamFinished: if (parseInt(text) >= root.startedAt - 1)
                root.ready = true
        }
    }

    // Never longer than this (a renderer that failed to start)
    Timer {
        running: root.showing
        interval: 25000
        onTriggered: root.ready = true
    }
}
