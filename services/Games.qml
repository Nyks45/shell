pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.utils

// Every launcher's games (Steam, Lutris, Faugus, Heroic) with their own
// settings, read by caelestia-gaming library. Kept up to date while a page
// shows them: check() compares a stamp of the launchers' files (a game
// installed in Steam or added in Faugus changes it) and reloads on a change.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-gaming`
    property var games: []
    // Per launcher: { installed, running, choices: [[value, label]], default, perf }
    property var launchers: ({})
    property string stamp
    property bool loaded
    // The games' options set for all of them (caelestia-gaming env)
    property var globalEnv: ({})

    readonly property var launcherNames: ({
            steam: "Steam",
            lutris: "Lutris",
            faugus: "Faugus",
            heroic: "Heroic"
        })
    // Launchers that rewrite their settings from memory: changes wait until they're closed
    readonly property var closeFirst: ["steam", "faugus", "heroic"]

    // [key, title, "on" value, "off" value, on by default (without the key)]
    readonly property var nvidiaOptions: [["NVPRESENT_ENABLE_SMOOTH_MOTION", Tr.tr("Smooth Motion"), "1", "0"], ["DXVK_NVAPI_VKREFLEX", Tr.tr("NVIDIA Reflex"), "1", "0"], ["PROTON_DLSS_UPGRADE", Tr.tr("Newest DLSS"), "1", "0"], ["PROTON_DLSS_INDICATOR", Tr.tr("DLSS indicator"), "1", "0"], ["PROTON_NVIDIA_LIBS", Tr.tr("CUDA and PhysX"), "1", "0"], ["__GL_THREADED_OPTIMIZATIONS", Tr.tr("Threaded optimisations (OpenGL)"), "1", "0"], ["__GL_SHARPEN_ENABLE", Tr.tr("Image sharpening"), "1", "0"]]
    readonly property var protonOptions: [["DXVK_HDR", Tr.tr("HDR"), "1", "0"], ["PROTON_NO_NTSYNC", Tr.tr("NTSync"), "0", "1", true], ["PROTON_USE_PIPEWIRE", Tr.tr("PipeWire audio"), "1", "0", true], ["PROTON_ENABLE_WAYLAND", Tr.tr("Native Wayland"), "1", "0"], ["PROTON_LOCAL_SHADER_CACHE", Tr.tr("Shader cache per game"), "1", "0"], ["PROTON_PREFER_SDL", Tr.tr("SDL for controllers"), "1", "0"], ["PROTON_DXVK_LOWLATENCY", Tr.tr("Low-latency DXVK"), "1", "0"], ["PROTON_LOG", Tr.tr("Proton logs"), "1", "0"]]

    function load(): void {
        if (!libProc.running)
            libProc.running = true;
        if (!envProc.running)
            envProc.running = true;
    }

    // Reload if a launcher's games changed (cheap: file times only)
    function check(): void {
        if (!loaded)
            load();
        else if (!stampProc.running && !libProc.running)
            stampProc.running = true;
    }

    function find(key: string): var {
        return games.find(g => g.key === key) ?? null;
    }

    function blocked(launcher: string): bool {
        return closeFirst.includes(launcher) && !!launchers[launcher]?.running;
    }

    // An option for all games: on?
    function globalOn(o: var): bool {
        const v = globalEnv[o[0]];
        return o[4] ? v === undefined || v !== o[3] : v === o[2];
    }

    // change: { proton?, env?: { KEY: value | null }, mangohud?, perf? }
    function set(key: string, change: var, what: string): void {
        Admin.exec([helper, "game-set"], what, () => root.load(), JSON.stringify(Object.assign({
            key
        }, change)));
    }

    function add(spec: var, done: var): void {
        Admin.exec([helper, "game-add"], Tr.tr("Add %1").arg(spec.title), ok => {
            root.load();
            if (typeof done === "function")
                done(ok);
        }, JSON.stringify(spec));
    }

    function remove(key: string, title: string): void {
        Admin.exec([helper, "game-remove", key], Tr.tr("Take %1 off the list").arg(title), () => root.load());
    }

    function play(game: var): void {
        Quickshell.execDetached(game.play);
    }

    Process {
        id: libProc

        command: [root.helper, "library"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.games = d.games ?? [];
                    root.launchers = d.launchers ?? {};
                    root.stamp = d.stamp ?? "";
                } catch (e) {}
                root.loaded = true;
            }
        }
    }

    Process {
        id: stampProc

        command: [root.helper, "library-stamp"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() && text.trim() !== root.stamp)
                    root.load();
            }
        }
    }

    Process {
        id: envProc

        command: [root.helper, "env"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.globalEnv = JSON.parse(text).values ?? {};
                } catch (e) {}
            }
        }
    }
}
