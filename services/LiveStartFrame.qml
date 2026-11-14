pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Login order, like Windows: the shell first, then the live wallpaper. The
// shell starts the renderer itself once it has drawn (not Hyprland at login,
// where both loaded at once and competed for the GPU). The renderer needs a
// moment to load its scene: until its first frame the background shows the
// last frame it saved (frame-<id>.png, from its --screenshot); "ready" turns
// true when it writes ready.bmp or a new frame (or was running already, or
// after a while), and the background fades it out.
Singleton {
    id: root

    readonly property string state: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    property string cachedFrame: ""
    readonly property string frame: cachedFrame
    // When the shell started (a frame written after it is the renderer's first)
    readonly property real startedAt: Date.now() / 1000
    property bool ready
    property bool checked
    property bool wasRunning
    property bool started
    property bool configured

    // Shown while the renderer loads
    readonly property bool showing: !!frame && !ready

    // Check if this session's renderer is already running (a shell restart) and
    // locate the saved frame on disk immediately without instantiating LiveWallpaper
    Process {
        running: true
        command: ["sh", "-c", `
            d="${root.state}/live-wallpaper"
            p=$(cat "$d/pid" 2>/dev/null)
            if [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ]; then
                echo "running"
                exit 0
            fi
            cfg="${root.configDir}/caelestia/live-wallpaper.json"
            if [ -f "$cfg" ]; then
                flat=$(tr -d '[:space:]' < "$cfg" 2>/dev/null)
                case "$flat" in
                    *'"screens":{}'*) exit 0 ;;
                    *'"screens":{"'*)
                        if [ -s "$d/current-frame.png" ]; then
                            echo "frame:$(readlink -f "$d/current-frame.png")"
                            exit 0
                        fi
                        for f in "$d"/frame-*.png; do
                            if [ -s "$f" ]; then
                                echo "frame:$f"
                                exit 0
                            fi
                        done
                        echo "configured"
                        exit 0
                        ;;
                esac
                exit 0
            fi
            if [ -s "$d/current-frame.png" ]; then
                echo "frame:$(readlink -f "$d/current-frame.png")"
                exit 0
            fi
            for f in "$d"/frame-*.png; do
                if [ -s "$f" ]; then
                    echo "frame:$f"
                    break
                fi
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "running") {
                    root.ready = true;
                    root.wasRunning = true;
                } else if (out === "configured") {
                    root.configured = true;
                } else if (out.startsWith("frame:")) {
                    root.cachedFrame = out.slice(6);
                }
                root.checked = true;
            }
        }
    }

    // Start the renderer right after the shell has drawn (once per login:
    // not when it was running already, e.g. after a shell restart)
    Timer {
        running: root.checked && !root.wasRunning && !root.started && (!!root.cachedFrame || root.configured)
        interval: 50
        onTriggered: {
            root.started = true;
            // through PATH (~/.local/bin links the shell's script; the dev
            // sandbox's stub catches it there)
            Quickshell.execDetached(["live-wallpaper", "start"]);
        }
    }

    // A new frame / ready marker from the renderer: it's drawing
    Timer {
        running: root.showing && root.started
        repeat: true
        interval: 150
        onTriggered: if (!statProc.running)
            statProc.running = true
    }

    Process {
        id: statProc

        command: ["stat", "-L", "-c", "%Y", `${root.state}/live-wallpaper/ready.bmp`, root.frame]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    if (parseInt(line) >= root.startedAt - 1) {
                        root.ready = true;
                        break;
                    }
                }
            }
        }
    }

    // Never longer than this (a renderer that failed to start)
    Timer {
        running: root.showing
        interval: 25000
        onTriggered: root.ready = true
    }
}
