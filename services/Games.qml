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
        // Its launcher is open and would write its old settings back when it quits: the change
        // waits (shown already) and is made as soon as the launcher is closed
        const g = find(key);
        if (g && blocked(g.launcher)) {
            const p = Object.assign({}, pending);
            const merged = Object.assign({}, p[key] ?? {}, change);
            if (change.env)
                merged.env = Object.assign({}, p[key]?.env ?? {}, change.env);
            p[key] = merged;
            pending = p;
            savePending();
            return;
        }
        Admin.exec([helper, "game-set"], what, () => root.load(), JSON.stringify(Object.assign({
            key
        }, change)));
    }

    // Changes waiting for their launcher to close: { key: change } (kept across restarts)
    property var pending: ({})

    // Other jobs waiting for a launcher to close: [{ launcher, command, what }] (kept too)
    property var queued: []

    // Run `command` now, or (its launcher open, which would undo it) once it's closed
    function whenClosed(launcher: string, command: list<string>, what: string, done: var): void {
        if (!blocked(launcher)) {
            Admin.exec(command, what, ok => {
                root.load();
                if (typeof done === "function")
                    done(ok);
            });
            return;
        }
        queued = [...queued.filter(q => q.what !== what), {
                launcher,
                command: Array.from(command),
                what
            }];
        savePending();
    }

    function isQueued(what: string): bool {
        return queued.some(q => q.what === what);
    }

    function unqueue(what: string): void {
        queued = queued.filter(q => q.what !== what);
        savePending();
    }

    function savePending(): void {
        pendingFile.setText(JSON.stringify({
            games: pending,
            jobs: queued
        }));
    }

    function hasPending(key: string): bool {
        return pending[key] !== undefined;
    }

    // The game as it will be: its settings with the waiting changes on top
    function withPending(g: var): var {
        const p = g ? pending[g.key] : undefined;
        if (!p)
            return g;
        const out = Object.assign({}, g, p);
        if (p.env) {
            const env = Object.assign({}, g.env ?? {});
            for (const [k, v] of Object.entries(p.env)) {
                if (v === null)
                    delete env[k];
                else
                    env[k] = v;
            }
            out.env = env;
        }
        return out;
    }

    // Keys whose waiting changes were just made (shown as "Saved")
    property var savedKeys: []
    // Launchers closed by "Save now" to start again once their waiting changes are made
    property var restartAfter: []

    function waitingFor(launcher: string): bool {
        return queued.some(q => q.launcher === launcher) || Object.keys(pending).some(k => k.startsWith(`${launcher}:`));
    }

    // "Save now": close the launcher (Steam: its own clean shutdown), make the waiting changes,
    // start it again
    function saveNow(launcher: string): void {
        if (launcher !== "steam" || !blocked(launcher))
            return;
        if (!restartAfter.includes(launcher))
            restartAfter = [...restartAfter, launcher];
        Quickshell.execDetached(["steam", "-shutdown"]);
        load();
    }

    function flushPending(): void {
        let changed = false;
        const saved = [];
        const p = Object.assign({}, pending);
        for (const key of Object.keys(p)) {
            const g = find(key);
            if (!g) {
                // Gone from its launcher
                if (loaded) {
                    delete p[key];
                    changed = true;
                }
                continue;
            }
            if (blocked(g.launcher))
                continue;
            const change = p[key];
            delete p[key];
            changed = true;
            saved.push(key);
            Admin.exec([helper, "game-set"], Tr.tr("Change %1's settings").arg(g.title), () => root.load(), JSON.stringify(Object.assign({
                key
            }, change)));
        }
        const waiting = [];
        for (const q of queued) {
            if (blocked(q.launcher) || !loaded)
                waiting.push(q);
            else {
                Admin.exec(q.command, q.what, () => root.load());
                changed = true;
            }
        }
        if (changed) {
            pending = p;
            queued = waiting;
            savePending();
            savedKeys = [...savedKeys, ...saved];
            savedTimer.restart();
        }
        // Closed by "Save now": started again when nothing waits for it any more
        for (const l of restartAfter) {
            if (!blocked(l) && loaded && !waitingFor(l)) {
                restartAfter = restartAfter.filter(x => x !== l);
                restartTimer.restart();
            }
        }
    }

    Timer {
        id: savedTimer

        interval: 8000
        onTriggered: root.savedKeys = []
    }

    // A moment for the saving jobs to finish before Steam reads its settings again
    Timer {
        id: restartTimer

        interval: 2500
        onTriggered: Quickshell.execDetached(["steam"])
    }

    onLaunchersChanged: flushPending()

    // A game writes Proton logs (its own option or the one for all games): each launch's log is
    // filed apart (caelestia-gamelogs.path), so the unit is on
    property bool logsUnitOn: false
    readonly property bool anyLogs: globalEnv.PROTON_LOG === "1" || games.some(g => g.env?.PROTON_LOG === "1") || Object.values(pending).some(p => p.env?.PROTON_LOG === "1")

    onAnyLogsChanged: {
        if (anyLogs && !logsUnitOn) {
            logsUnitOn = true;
            Quickshell.execDetached(["systemctl", "--user", "enable", "--now", "caelestia-gamelogs.path"]);
        }
    }

    // While changes wait, look for their launcher closing (reading the library also reads that)
    Timer {
        running: Object.keys(root.pending).length > 0 || root.queued.length > 0
        repeat: true
        interval: 4000
        onTriggered: root.load()
    }

    FileView {
        id: pendingFile

        path: `${Paths.state}/games-pending.json`
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text()) ?? {};
                root.pending = d.games ?? {};
                root.queued = d.jobs ?? [];
            } catch (e) {}
        }
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
