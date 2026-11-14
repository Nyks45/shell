pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
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
    readonly property string monitorNames: Quickshell.screens.map(s => s.name).join(",")
    readonly property string defaultFrame: `${state}/live-wallpaper/current-frame.png`
    property string cachedFrame: CUtils.fileExists(defaultFrame) && CUtils.fileExists(`${configDir}/caelestia/live-wallpaper.json`) ? defaultFrame : ""
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
    // locate the saved frame on disk while launching the renderer immediately
    // without instantiating LiveWallpaper
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
            has_live=0
            if [ -f "$cfg" ]; then
                flat=$(tr -d '[:space:]' < "$cfg" 2>/dev/null)
                case "$flat" in
                    *'"screens":{}'*) echo "none"; exit 0 ;;
                    *'"screens":{"'*) has_live=1 ;;
                    *) echo "none"; exit 0 ;;
                esac
            fi
            frame=""
            if [ -s "$d/current-frame.png" ]; then
                frame=$(readlink -f "$d/current-frame.png")
            else
                for f in "$d"/frame-*.png; do
                    if [ -s "$f" ]; then
                        frame="$f"
                        break
                    fi
                done
            fi
            lw=$(command -v live-wallpaper || echo '${Quickshell.shellDir}/assets/live-wallpaper')
            if [ "$has_live" = 1 ] || [ -n "$frame" ]; then
                (LIVE_WALLPAPER_MONITORS="${root.monitorNames}" exec "$lw" start) >/dev/null 2>&1 </dev/null &
                if [ -n "$frame" ]; then
                    echo "frame:$frame"
                else
                    echo "configured"
                fi
            else
                echo "none"
            fi
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "running") {
                    root.cachedFrame = "";
                    root.ready = true;
                    root.wasRunning = true;
                } else if (out === "none" || !out) {
                    root.cachedFrame = "";
                    root.ready = true;
                } else if (out === "configured") {
                    root.cachedFrame = "";
                    root.configured = true;
                    root.started = true;
                } else if (out.startsWith("frame:")) {
                    root.cachedFrame = out.slice(6);
                    root.started = true;
                }
                root.checked = true;
            }
        }
    }

    // Fallback launcher if not already started above
    Timer {
        running: root.checked && !root.wasRunning && !root.started && (!!root.cachedFrame || root.configured)
        interval: 50
        onTriggered: {
            root.started = true;
            // through PATH (~/.local/bin links the shell's script; the dev
            // sandbox's stub catches it there), or packaged fallback
            Quickshell.execDetached(["sh", "-c", `lw=$(command -v live-wallpaper || echo '${Quickshell.shellDir}/assets/live-wallpaper'); LIVE_WALLPAPER_MONITORS="${root.monitorNames}" exec "$lw" start`]);
        }
    }

    // A new frame / ready marker from the renderer: it's drawing
    Timer {
        running: root.showing && root.started
        repeat: true
        interval: 80
        onTriggered: if (!statProc.running)
            statProc.running = true
    }

    Process {
        id: statProc

        command: ["sh", "-c", `
            rb="${root.state}/live-wallpaper/ready.bmp"
            if [ -s "$rb" ]; then
                stat -L -c "%Y" "$rb" 2>/dev/null
            else
                stat -L -c "%Y" "${root.frame}" 2>/dev/null
            fi
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    if (parseInt(line) >= Math.floor(root.startedAt)) {
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
