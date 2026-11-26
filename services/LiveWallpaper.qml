pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// Live wallpapers (Wallpaper Engine wallpapers, drawn by linux-wallpaperengine)
// for the settings app; it replaces the Linux Wallpaper Engine GUI. The
// choices live in live-wallpaper.json; the `live-wallpaper` script
// (assets/live-wallpaper, linked to ~/.local/bin) starts the renderer from
// them, here and at login. assets/live-wallpaper-scan.py finds the
// wallpapers, tests them, reads the Workshop and writes the playlists.
//
// live-wallpaper.json: { screens: { "*" | monitor: folder | "playlist:NAME" },
//   fps, postProcessing (off|normal|ultra, default ultra), pauseOnFullscreen, pauseOnlyActive, pauseIgnore[], silent, volume,
//   noAutomute, audioProcessing, scaling, clamp, span, disableMouse,
//   disableParallax, disableParticles, assetsDir, extraFolders[],
//   overrides: { folder: { scaling?, volume?, properties?: { name: value } } },
//   history: { folder: ms }, compat: { folder: { grade, errors, manual? } },
//   playlists: [{ name, items[], delay (min), order }], sortBy, showMature, ... }
Singleton {
    id: root

    property var config: ({})
    property var wallpapers: []
    property bool scanning
    property bool hasScript
    property bool hasEngine
    property bool running
    readonly property bool automaticPlaybackActive: !waitingAfterCrash && !crashProtectionActive && (setting("startAtLogin", true) || seenRunning)
    readonly property string defaultAudioOutput: Audio.sink?.ready ? Audio.sink.name : ""
    property string previousAudioOutput
    // Paused (saved: the start script pauses again after restarts and logins)
    readonly property bool paused: config.paused ?? false
    property string engineVersion
    property string engineLatest
    property string assetsDetected
    // Compatibility scan: done / total while it runs
    property int testDone
    property int testTotal
    readonly property bool testing: testProc.running
    // The Workshop page shown: { items, page, pages, total, tagGroups, error }
    property var workshopPage: ({
            items: []
        })
    property bool workshopLoading
    // Its filter groups (Type, Age Rating, Genre, Resolution, ...), kept once known
    property var workshopTagGroups: []
    // Steam sign-in (assets/live-wallpaper-steam.py; tokens stay in the keyring)
    property bool steamSignedIn
    property string steamAccount
    // While signing in: { state: scan|confirm|done|expired|error, qr, error }
    property var steamLogin: null
    // Workshop ids subscribed from here and still downloading
    property var steamPending: []
    property string steamError
    readonly property bool steamBusy: steamSubProc.running
    // Download into the own library (DepotDownloader): { id, state: qr|progress|done|error, qr, percent, error }
    property var download: null
    readonly property string steamHelper: `${Quickshell.shellDir}/assets/live-wallpaper-steam.py`
    // Details of the Workshop item opened (description, views), or null
    property var workshopItem: null
    property bool workshopItemLoading
    property var workshopUpdates: []
    property bool checkingWorkshopUpdates
    property string workshopUpdatesError
    property var updateQueue: []
    // "Update all": the ones whose download failed (the queue goes on without them)
    property var updateFailures: []
    property bool pendingRandom

    readonly property string configPath: `${Paths.config}/live-wallpaper.json`
    readonly property string scanner: `${Quickshell.shellDir}/assets/live-wallpaper-scan.py`
    readonly property string scriptBin: `${Quickshell.shellDir}/assets/live-wallpaper`

    function runScript(arg: string): void {
        Quickshell.execDetached(["sh", "-c", `s=$(command -v live-wallpaper || echo '${root.scriptBin}'); exec "$s" "$1"`, "sh", arg]);
    }
    readonly property var screens: resolveScreens(config.screens ?? {})
    readonly property var activeScreens: ruleSelection ? resolveScreens(ruleSelection.screens) : screens
    readonly property var profiles: setting("profiles", [])
    property var ruleSelection: null
    property bool screensaverActive
    readonly property var screensaverScreens: {
        const target = setting("screensaverWallpaper", "");
        if (target.startsWith("profile:")) {
            const profile = profiles.find(p => p.name === target.slice(8));
            return profile ? resolveScreens(profile.screens) : screens;
        }
        return target ? { "*": target } : activeScreens;
    }

    function resolveScreens(assigned: var): var {
        const entries = Object.entries(assigned);
        entries.sort(([left], [right]) => Number(resolveDisplay(left) === left) - Number(resolveDisplay(right) === right));
        const resolved = {};
        for (const [name, wallpaper] of entries)
            resolved[resolveDisplay(name)] = wallpaper;
        return resolved;
    }

    function saveProfile(name: string): void {
        name = name.trim();
        if (!name || !Object.keys(screens).length)
            return;
        setQuiet("profiles", profiles.filter(p => p.name !== name).concat([{
                name, screens: config.screens, span: setting("span", false)
            }]));
    }
    readonly property var mutedOutputs: {
        const saved = setting("mutedOutputs", []);
        return Array.isArray(saved) ? [...new Set(saved.map(name => resolveDisplay(name)))] : [];
    }

    function monitorIdentity(monitor: var): var {
        return {
            make: monitor?.make ?? "",
            model: monitor?.model ?? "",
            serial: monitor?.serial ?? "",
            description: monitor?.description ?? "",
            x: monitor?.x ?? null,
            y: monitor?.y ?? null
        };
    }

    function resolveDisplay(name: string): string {
        const mode = setting("monitorIdentification", "connector");
        const saved = setting("monitorIdentities", {})[name];
        if (mode === "connector" || !saved || name === "*")
            return name;
        const same = mode === "serial" ? m => !!saved.serial && m.serial === saved.serial
            && m.make === saved.make && m.model === saved.model
            : mode === "layout" ? m => saved.x != null && saved.y != null && m.x === saved.x && m.y === saved.y
            : m => !!saved.description && m.description === saved.description;
        const matches = Hypr.monitors.values.filter(m => same(monitorIdentity(m.lastIpcObject)));
        return matches.length === 1 ? matches[0].name : name;
    }
    // The wallpaper on all screens (or the first screen's)
    readonly property string current: screens["*"] ?? Object.values(screens)[0] ?? ""
    // Full-size frame of the wallpaper shown, saved by the renderer at start
    // (for the lock screen): a sharp preview, where the Workshop one is small
    readonly property string currentFrame: currentInfo ? `${wallpaperStatePath}/frame-${currentInfo.path.split("/").pop()}.png` : ""
    readonly property string displayedFrame: `${wallpaperStatePath}/current-frame.png`
    // The wallpaper shown (a playlist's current one too)
    readonly property var currentInfo: {
        const p = wallpaperPath(current);
        return wallpapers.find(w => w.path === p) ?? null;
    }
    readonly property bool hasWebOutput: Object.values(activeScreens).some(assignment =>
        wallpapers.some(w => w.path === wallpaperPath(assignment) && w.type === "web"))
    readonly property var playlists: config.playlists ?? []

    function wallpaperPath(assignment: string): string {
        return assignment.startsWith("playlist:") ? playlistPath(assignment.slice(9)) : assignment;
    }

    function setting(key: string, fallback: var): var {
        return config[key] ?? fallback;
    }

    function save(next: var): void {
        config = next;
        file.setText(JSON.stringify(next, null, 4) + "\n");
    }

    function patch(changes: var): void {
        if (changes.screens || changes.mutedOutputs || changes.monitorIdentification) {
            changes.monitorIdentities = Object.assign({}, config.monitorIdentities ?? {});
            for (const monitor of Hypr.monitors.values)
                changes.monitorIdentities[monitor.name] = monitorIdentity(monitor.lastIpcObject);
        }
        save(Object.assign({}, config, changes));
    }

    // A playback setting: the renderer restarts with it (except volume, updated live on the PipeWire stream when active)
    function set(key: string, value: var): void {
        patch({
            [key]: value
        });
        if (key === "volume" && running && !setting("silent", true) && mutedOutputs.length === 0) {
            if (setRendererVolume(Math.max(0, Math.min(1, Number(value) / 100))))
                return;
        }
        if (current)
            restartTimer.restart();
    }

    // Save a setting without restarting playback.
    function setQuiet(key: string, value: var): void {
        patch({
            [key]: value
        });
    }

    function setGraphicsPreset(settings: var): void {
        patch(settings);
        if (current)
            restartTimer.restart();
    }

    function resetSettings(): void {
        const preserved = ["screens", "overrides", "history", "compat", "playlists", "playlistNow", "playlistBoot",
            "profiles", "assetsDir", "extraFolders", "favourites", "span", "monitorIdentities"];
        const next = {};
        for (const key of preserved)
            if (config[key] !== undefined)
                next[key] = config[key];
        save(next);
        GlobalConfig.background.desktopIconOpacity = 1;
        if (current)
            restartTimer.restart();
    }

    // Wallpapers the config refers to by a path that isn't theirs any more
    // (Steam's folders, from before the own library had a copy): point them
    // at where the scan found them. Quiet (no restart): the running renderer
    // keeps its folder until it starts again.
    function migratePaths(): void {
        const byName = {};
        for (const w of wallpapers)
            byName[w.path.split("/").pop()] = w.path;
        const known = new Set(wallpapers.map(w => w.path));
        const text = JSON.stringify(config);
        const out = text.replace(/"(\/[^"]*\/(?:workshop\/content\/431960|projects\/defaultprojects)\/([^"\/]+))"/g, (m, p, name) => !known.has(p) && byName[name] && byName[name] !== p ? JSON.stringify(byName[name]) : m);
        if (out !== text)
            save(JSON.parse(out));
    }

    // ---- Playback rules (Wallpaper Engine's "Other application focused /
    // maximized / playing audio" and its per-app rules), run here: the
    // renderer only knows "fullscreen". Actions: run, mute, pause, stop (frees
    // memory; starts again when the rule no longer holds). The strongest
    // applies (stop > pause > mute). A pause set by hand always wins.
    readonly property var playbackRules: Object.assign({
        focused: "run",
        maximized: "run",
        audio: setting("noAutomute", false) ? "run" : "mute",
        fullscreen: setting("pauseOnFullscreen", true) ? "pause" : "run",
        battery: "run",
        displayAsleep: "run"
    }, config.playbackRules ?? {})
    // [{ app: window class (part of it), when: running|focused|maximized|fullscreen|audio, action }]
    readonly property var appRules: config.appRules ?? []
    readonly property bool shellFullscreenRule: config.playbackRules?.fullscreen !== undefined || appRules.length > 0
    readonly property bool shellAudioRule: config.playbackRules?.audio !== undefined || appRules.some(r => r.when === "audio")
    readonly property bool readsAudioRules: shellAudioRule && (playbackRules.audio !== "run" || appRules.some(r => r.when === "audio"))
    readonly property bool hasActiveRules: playbackRules.focused !== "run" || playbackRules.maximized !== "run"
        || readsAudioRules || (shellFullscreenRule && playbackRules.fullscreen !== "run")
        || playbackRules.battery !== "run" || playbackRules.displayAsleep !== "run" || appRules.length > 0
    property var audioRuleStreams: []
    property bool wallpaperDisplaysAsleep
    property var sleepingOutputs: []
    property string publishedOutputPlayback: ""
    readonly property string wallpaperStatePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/live-wallpaper`
    readonly property string outputPlaybackPath: `${wallpaperStatePath}/output-playback.json`
    readonly property var transitionTypes: [
        ["hold", Tr.tr("No animation (hold until ready)")],
        ["none", Tr.tr("None")],
        ["random", Tr.tr("Random")],
        ["0", Tr.tr("Fade")],
        ["18", Tr.tr("Fade to black")],
        ["1", Tr.tr("Mosaic")],
        ["2", Tr.tr("Diffuse")],
        ["3", Tr.tr("Horizontal slide")],
        ["4", Tr.tr("Vertical slide")],
        ["5", Tr.tr("Horizontal fade")],
        ["6", Tr.tr("Vertical fade")],
        ["7", Tr.tr("Clouds")],
        ["8", Tr.tr("Burnt paper")],
        ["9", Tr.tr("Circular")],
        ["10", Tr.tr("Zipper")],
        ["11", Tr.tr("Door")],
        ["12", Tr.tr("Lines")],
        ["22", Tr.tr("Radial wipe")],
        ["13", Tr.tr("Zoom")],
        ["19", Tr.tr("Twister")],
        ["14", Tr.tr("Drip")],
        ["15", Tr.tr("Pixelate")],
        ["16", Tr.tr("Bricks")],
        ["17", Tr.tr("Paint")],
        ["20", Tr.tr("Black hole")],
        ["21", Tr.tr("CRT")],
        ["23", Tr.tr("Glass shatter")],
        ["24", Tr.tr("Bullets")],
        ["25", Tr.tr("Ice")],
        ["26", Tr.tr("Boilover")]
    ]
    property var presentedScreens: null
    property var switchingWallpaper: null
    property real transitionProgress
    property bool transitionPrepared
    property var drawnTransitionOutputs: ({})

    function transitionDrawn(output: string): void {
        if (!switchingWallpaper || !transitionPrepared || drawnTransitionOutputs[output])
            return;
        drawnTransitionOutputs[output] = true;
        if (Object.keys(switchingWallpaper.outputs).every(name => drawnTransitionOutputs[name]))
            transitionAcknowledge.setText("drawn\n");
    }

    function selectedWallpapers(): var {
        const selected = {};
        for (const [name, assignment] of Object.entries(activeScreens))
            selected[name] = wallpaperPath(assignment);
        return selected;
    }

    function launchRenderer(): void {
        const selected = selectedWallpapers();
        const changed = presentedScreens && JSON.stringify(presentedScreens) !== JSON.stringify(selected);
        const mode = setting("browseTransition", "none");
        const photo = `${wallpaperStatePath}/current-frame.png`;
        transitionAnimation.stop();
        switchingWallpaper = null;
        transitionPrepared = false;
        drawnTransitionOutputs = {};
        if (running && changed && mode !== "none" && Object.keys(selected).length && CUtils.fileExists(photo)) {
            const old = presentedScreens;
            const common = Hypr.monitors.values.filter(m => old["*"] || old[m.name]).sort((a, b) => a.name < b.name ? -1 : 1);
            const geometry = common.map(m => m.lastIpcObject).filter(m => m && m.width && m.height);
            const sizes = geometry.map(m => m.transform % 2 === 1 ? [m.height, m.width] : [m.width, m.height]);
            const width = sizes.reduce((sum, size) => sum + size[0], 0);
            const height = Math.max(...sizes.map(size => size[1]));
            const outputs = {};
            let x = 0;
            for (let i = 0; i < geometry.length; ++i) {
                const [w, h] = sizes[i];
                const name = geometry[i].name;
                if (selected["*"] || selected[name])
                    outputs[name] = Qt.rect(x / width, 0, w / width, h / height);
                x += w;
            }
            const effects = transitionTypes.slice(3).map(t => t[0]);
            const allowed = setting("transitionPool", effects).filter(e => effects.includes(e));
            const pool = allowed.length ? allowed : effects;
            const effect = mode === "random" ? pool[Math.floor(Math.random() * pool.length)] : mode;
            if (Object.keys(outputs).length) {
                transitionProgress = 0;
                switchingWallpaper = {
                    id: String(Date.now()), photo, outputs,
                    effect: effect === "hold" ? -1 : Number(effect),
                    duration: effect === "hold" ? 0 : setting("transitionDuration", 350)
                };
            }
        }
        startProc.selection = selected;
        startProc.running = true;
    }

    FileView {
        path: root.switchingWallpaper ? `${root.wallpaperStatePath}/transition-prepare-${root.switchingWallpaper.id}` : ""
        watchChanges: !!root.switchingWallpaper
        printErrors: false
        onFileChanged: reload()
        onTextChanged: if (root.switchingWallpaper && text().trim() === "prepared")
            root.transitionPrepared = true
    }

    FileView {
        id: transitionAcknowledge
        path: root.switchingWallpaper ? `${root.wallpaperStatePath}/transition-drawn-${root.switchingWallpaper.id}` : ""
        printErrors: false
    }

    FileView {
        path: root.switchingWallpaper ? `${root.wallpaperStatePath}/transition-ready-${root.switchingWallpaper.id}` : ""
        watchChanges: !!root.switchingWallpaper
        printErrors: false
        onFileChanged: reload()
        onTextChanged: if (root.switchingWallpaper && text().trim() === "ready")
            transitionAnimation.start()
    }

    NumberAnimation {
        id: transitionAnimation

        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: root.switchingWallpaper?.duration ?? 0
        onFinished: root.switchingWallpaper = null
    }
    readonly property bool crashProtectionActive: {
        if (!setting("protectAfterCrash", false))
            return false;
        try {
            const saved = JSON.parse(crashHold.text());
            const selection = config.screens ?? {};
            const keys = Object.keys(selection);
            return keys.length > 0 && keys.length === Object.keys(saved).length
                && keys.every(name => selection[name] === saved[name]);
        } catch (e) {
            return false;
        }
    }
    // What the rules do right now, and why (shown on the settings page)
    property string ruleAction: "run"
    property string ruleReason
    property bool rulePausePending

    function hasMonitorRules(rules: var, list: var): bool {
        return [...Object.values(rules), ...list.map(rule => rule.action)]
            .some(action => action === "pauseMonitor" || action === "stopMonitor");
    }

    function setPlaybackRule(key: string, action: string): void {
        const rules = Object.assign({}, config.playbackRules ?? {}, { [key]: action });
        if ((key === "fullscreen" && !shellFullscreenRule) || (key === "audio" && !shellAudioRule)
            || hasMonitorRules(rules, appRules) !== hasMonitorRules(playbackRules, appRules))
            set("playbackRules", rules);
        else
            setQuiet("playbackRules", rules);
    }

    function setAppRules(list: var): void {
        const nextFullscreen = config.playbackRules?.fullscreen !== undefined || list.length > 0;
        const nextAudio = config.playbackRules?.audio !== undefined || list.some(r => r.when === "audio");
        if (nextFullscreen !== shellFullscreenRule || nextAudio !== shellAudioRule
            || hasMonitorRules(playbackRules, list) !== hasMonitorRules(playbackRules, appRules))
            set("appRules", list);
        else
            setQuiet("appRules", list);
    }

    FileView {
        id: outputPlayback
        path: root.outputPlaybackPath
        printErrors: false
    }

    FileView {
        id: crashHold
        path: `${root.wallpaperStatePath}/crash-hold.json`
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // The frame cap applies to the whole renderer, so every wallpaper output must be covered.
    property bool coverSupported
    property bool coverSent

    function screenCovered(wins: var): bool {
        const monitors = Hypr.monitors.values.filter(m => activeScreens[m.name] || activeScreens["*"]);
        return monitors.length > 0 && monitors.every(m => {
            const workspace = m.activeWorkspace?.id;
            return workspace !== undefined && wins.some(t => {
                const window = t.lastIpcObject;
                return window?.fullscreen === 2 && window.monitor === m.id
                    && !window.hidden && window.mapped !== false && t.workspace?.id === workspace;
            });
        });
    }

    function sendCover(covered: bool): void {
        if (!coverSupported || covered === coverSent)
            return;
        coverSent = covered;
        Quickshell.execDetached(["live-wallpaper", covered ? "cover" : "uncover"]);
    }

    Process {
        running: true
        command: ["grep", "-qa", "Covered: ", "/opt/linux-wallpaperengine/liblinux-wallpaperengine-lib.so"]
        onExited: code => root.coverSupported = code === 0
    }

    function evaluateRules(reapply: bool): void {
        const rank = {
            run: 0,
            mute: 1,
            pause: 2,
            stop: 3
        };
        const visibleWs = Hypr.monitors.values.map(m => m.activeWorkspace?.id);
        const wins = Hypr.toplevels.values.filter(t => t.lastIpcObject && !t.lastIpcObject.hidden && visibleWs.includes(t.workspace?.id));
        const monitorNames = new Map(Hypr.monitors.values.map(m => [m.id, m.name]));
        const outputs = {};
        let outputReason = "";
        const considerOutputs = (action, reason, names) => {
            const local = action === "stopMonitor" ? "stop" : "pause";
            for (const name of names) {
                if (!name || !(activeScreens[name] || activeScreens["*"]))
                    continue;
                if ((rank[outputs[name]] ?? 0) < rank[local]) {
                    outputs[name] = local;
                    outputReason = reason;
                }
            }
        };
        const isMax = t => {
            const o = t.lastIpcObject;
            if (o.fullscreen === 1)
                return true;
            // Desktop mode's maximize: a floating window over the work area
            const sz = o.size ?? [0, 0];
            const mon = Hypr.monitors.values.find(m => m.id === o.monitor);
            return !!mon && sz[0] >= mon.width / mon.scale * 0.95 && sz[1] >= mon.height / mon.scale * 0.85;
        };
        const playing = audioRuleStreams;
        const active = Hypr.activeToplevel;
        const focused = !!active && wins.includes(active);
        let best = "run", why = "";
        let selection = null, selectionReason = "";
        const consider = (action, reason, names = []) => {
            if (action === "pauseMonitor" || action === "stopMonitor") {
                considerOutputs(action, reason, names);
                return;
            }
            if ((rank[action] ?? 0) > rank[best]) {
                best = action;
                why = reason;
            }
        };
        const overriddenWindows = new Set();
        const overriddenStreams = new Set();
        for (const r of appRules) {
            const app = String(r.app ?? "").toLowerCase();
            if (!app)
                continue;
            const all = Hypr.toplevels.values.filter(t => String(t.lastIpcObject?.class ?? "").toLowerCase().includes(app));
            const shown = all.filter(t => wins.includes(t));
            const matchingStreams = playing.filter(p => p.identity.toLowerCase().includes(app));
            const matchingWindows = r.when === "running" ? all : r.when === "focused" ? all.filter(t => t === active) : r.when === "maximized" ? shown.filter(isMax) : r.when === "fullscreen" ? shown.filter(t => t.lastIpcObject.fullscreen === 2) : [];
            if (matchingWindows.length || (r.when === "audio" && matchingStreams.length)) {
                for (const window of matchingWindows)
                    overriddenWindows.add(window);
                for (const stream of matchingStreams)
                    overriddenStreams.add(stream);
                const reason = Tr.tr("rule for %1").arg(r.app);
                if ((r.action ?? "").startsWith("load")) {
                    if (!selection) {
                        if (r.action === "loadProfile")
                            selection = profiles.find(p => p.name === r.target) ?? null;
                        else if (r.action === "loadPlaylist" && playlist(r.target)?.items.length)
                            selection = { screens: { "*": `playlist:${r.target}` }, span: true };
                        else if (r.action === "loadWallpaper" && r.target)
                            selection = { screens: { "*": r.target }, span: true };
                        if (selection)
                            selectionReason = reason;
                    }
                } else {
                    consider(r.action, reason,
                        (r.when === "audio" ? shown : matchingWindows).map(window => monitorNames.get(window.lastIpcObject?.monitor)));
                }
            }
        }
        if (focused && !overriddenWindows.has(active))
            consider(playbackRules.focused, Tr.tr("an app is focused"), [monitorNames.get(active.lastIpcObject.monitor)]);
        const maximized = wins.filter(t => !overriddenWindows.has(t) && isMax(t));
        if (maximized.length)
            consider(playbackRules.maximized, Tr.tr("an app is maximized"), maximized.map(t => monitorNames.get(t.lastIpcObject.monitor)));
        const fullscreen = wins.filter(t => {
            const appId = String(t.lastIpcObject.class ?? "").toLowerCase();
            return t.lastIpcObject.fullscreen === 2 && !overriddenWindows.has(t)
                && (!setting("pauseOnlyActive", false) || t === active)
                && !setting("pauseIgnore", []).some(id => String(id).toLowerCase() === appId);
        });
        if (shellFullscreenRule && fullscreen.length)
            consider(playbackRules.fullscreen, Tr.tr("an app is fullscreen"), fullscreen.map(t => monitorNames.get(t.lastIpcObject.monitor)));
        const playingApp = playing.find(p => !overriddenStreams.has(p));
        if (shellAudioRule && playingApp)
            consider(playbackRules.audio, Tr.tr("%1 is playing audio").arg(playingApp.name));
        if (UPower.onBattery)
            consider(playbackRules.battery, Tr.tr("running on battery"));
        if (wallpaperDisplaysAsleep || (sleepingOutputs.length && playbackRules.displayAsleep.endsWith("Monitor")))
            consider(playbackRules.displayAsleep, Tr.tr("wallpaper displays are asleep"), sleepingOutputs);
        const outputState = JSON.stringify(outputs);
        if ((hasMonitorRules(playbackRules, appRules) || publishedOutputPlayback) && outputState !== publishedOutputPlayback) {
            publishedOutputPlayback = outputState;
            outputPlayback.setText(outputState);
        }
        if (JSON.stringify(selection) !== JSON.stringify(ruleSelection)) {
            const previousLists = playingPlaylists();
            ruleSelection = selection;
            for (const name of playingPlaylists())
                if (!previousLists.includes(name))
                    startPlaylist(name);
            restartTimer.restart();
        }
        ruleReason = why || outputReason || selectionReason;
        // Covered: only while it draws (a pause or stop rule has it not drawing at all; a covered
        // sent then would be undone the moment it's shown again)
        if (running && !paused && (best === "run" || best === "mute"))
            sendCover(screenCovered(wins));
        if (best === ruleAction && !reapply && best !== "mute")
            return;
        const prev = ruleAction;
        ruleAction = best;
        // Undo the old action, then do the new one
        if (prev === "mute" && best !== "mute")
            muteRenderer(false);
        if (prev === "pause" && best !== "pause") {
            rulePausePending = false;
            if (!paused)
                runScript("resume");
        }
        if (prev === "stop" && best !== "stop")
            restartTimer.restart();
        if (best === "mute")
            muteRenderer(true);
        if (best === "pause" && !paused)
            rulePausePending = true;
        if (best === "stop")
            runScript("stop");
    }

    // A launch command returns before its renderer can present anything.
    // Wait for the current launch's saved frame before stopping that process.
    Timer {
        running: root.rulePausePending && !root.paused && !startProc.running
        repeat: true
        triggeredOnStart: true
        interval: 200
        onTriggered: if (!ruleReadyProbe.running)
            ruleReadyProbe.running = true
    }

    Process {
        id: ruleReadyProbe

        command: ["sh", "-c", `s=$(command -v live-wallpaper || echo '${root.scriptBin}'); exec "$s" ready`]
        onExited: code => {
            if (code !== 0 || !root.rulePausePending || root.ruleAction !== "pause"
                || root.paused || startProc.running)
                return;
            root.rulePausePending = false;
            root.runScript("pause-ready");
        }
    }

    // The renderer's sound (its PipeWire stream), muted or scaled live
    function muteRenderer(mute: bool): void {
        for (const st of Audio.streams) {
            if (isRendererStream(st) && st.audio)
                st.audio.muted = mute;
        }
    }

    function isRendererStream(stream: var): bool {
        const props = stream.properties ?? {};
        const who = `${props["application.process.binary"] ?? ""} ${props["application.name"] ?? ""}`.toLowerCase();
        const pid = rendererPid.text().trim();
        return who.includes("wallpaperengine") && (pid && props["application.process.id"]
            ? pid === String(props["application.process.id"]) : !screensaverActive);
    }

    FileView {
        id: rendererPid

        path: `${root.wallpaperStatePath}/pid`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    function setRendererVolume(vol: real): bool {
        let updated = false;
        for (const st of Audio.streams) {
            if (isRendererStream(st) && st.audio) {
                st.audio.volume = vol;
                updated = true;
            }
        }
        return updated;
    }

    // Favourites (Wallpaper Engine's heart), by folder
    function isFavourite(path: string): bool {
        return (config.favourites ?? []).includes(path);
    }

    function toggleFavourite(path: string): void {
        const fav = config.favourites ?? [];
        setQuiet("favourites", fav.includes(path) ? fav.filter(p => p !== path) : fav.concat([path]));
    }

    function info(path: string): var {
        return wallpapers.find(w => w.path === path) ?? null;
    }

    function compat(path: string): var {
        const c = (config.compat ?? {})[path];
        return c ? Object.assign({}, c, {
            grade: c.manual || c.grade
        }) : null;
    }

    // A grade set by hand wins over tests
    function setCompat(path: string, grade: string): void {
        const all = Object.assign({}, config.compat ?? {});
        all[path] = Object.assign({}, all[path] ?? {}, {
            manual: grade || undefined
        });
        if (!grade)
            delete all[path].manual;
        patch({
            compat: all
        });
    }

    // On every screen ("*") or one monitor; a folder or "playlist:NAME"
    function apply(target: string, screen: string): void {
        randomPick = false;
        const s = screen && screen !== "*" ? Object.assign({}, screens) : {};
        if (screen && screen !== "*" && s["*"]) {
            // From "same on all" to per monitor: the others keep it
            for (const m of Hypr.monitors.values)
                s[m.name] = s["*"];
            delete s["*"];
        }
        s[screen || "*"] = target;
        const changes = {
            screens: s
        };
        if (!target.startsWith("playlist:"))
            changes.history = Object.assign({}, config.history ?? {}, {
                [target]: Date.now()
            });
        changes.paused = false; // a new wallpaper plays
        patch(changes);
        if (target.startsWith("playlist:"))
            startPlaylist(target.slice(9));
        // Caelestia's own wallpaper stays hidden under the live one (the script
        // still sets it, for the lock screen and the colours)
        GlobalConfig.background.wallpaperEnabled = false;
        restartTimer.restart();
        checkPending = true; // checked once the restart is done (see startProc)
    }

    // Nothing on one monitor (or all)
    function stopScreen(screen: string): void {
        const s = Object.assign({}, screens);
        if (s["*"] && screen !== "*") {
            for (const m of Hypr.monitors.values)
                s[m.name] = s["*"];
            delete s["*"];
        }
        delete s[screen];
        patch({
            screens: s
        });
        if (Object.keys(s).length)
            restartTimer.restart();
        else
            useStatic(); // the last one: the normal wallpaper shows again
    }

    function stop(): void {
        patch({
            screens: {},
            paused: false
        });
        runScript("stop");
        runningTimer.restart();
    }

    // Back to a normal wallpaper: the live one stops, Caelestia's shows again
    function useStatic(): void {
        if (Object.keys(screens).length)
            stop();
        GlobalConfig.background.wallpaperEnabled = true;
    }

    function usable(w: var): bool {
        return (compat(w.path)?.grade ?? "") !== "broken" && (w.rating === "g" || w.rating === "" || setting("showMature", false));
    }

    function random(): void {
        // From a shortcut before the list was read: read it first
        if (!wallpapers.length) {
            pendingRandom = true;
            refresh();
            return;
        }
        // Ones known to work first; untested ones only when there are none
        const pool = wallpapers.filter(w => w.path !== current && usable(w));
        const good = pool.filter(w => ["perfect", "minor"].includes(compat(w.path)?.grade ?? ""));
        const from = good.length ? good : pool;
        if (from.length > 0) {
            apply(from[Math.floor(Math.random() * from.length)].path, "*");
            randomPick = true;
        }
    }

    // A random pick that turns out broken is replaced by another (a few times)
    property bool randomPick
    property string lastScan
    property int randomTries

    function togglePause(): void {
        const p = !paused;
        setQuiet("paused", p);
        runScript(p ? "pause" : "resume");
    }

    // Per wallpaper: scaling, volume, its own properties (--set-property)
    function override(path: string): var {
        return (config.overrides ?? {})[path] ?? {};
    }

    function setOverride(path: string, key: string, value: var): void {
        const overrides = Object.assign({}, config.overrides ?? {});
        const o = Object.assign({}, overrides[path] ?? {});
        if (value === undefined || value === null)
            delete o[key];
        else
            o[key] = value;
        if (Object.keys(o).length)
            overrides[path] = o;
        else
            delete overrides[path];
        patch({
            overrides
        });
        if (Object.values(screens).includes(path))
            restartTimer.restart();
    }

    function setProperty(path: string, name: string, value: var): void {
        const props = Object.assign({}, override(path).properties ?? {});
        if (value === undefined || value === null)
            delete props[name];
        else
            props[name] = value;
        setOverride(path, "properties", Object.keys(props).length ? props : null);
    }

    function resetOverrides(path: string): void {
        const overrides = Object.assign({}, config.overrides ?? {});
        delete overrides[path];
        patch({
            overrides
        });
        if (Object.values(screens).includes(path))
            restartTimer.restart();
    }

    // Playlists, run here (not by the renderer: it only reads them from a
    // Wallpaper Engine install). Like Wallpaper Engine's: change on a timer,
    // when logging in, by time of day, by day of week, or never (by hand);
    // in order or shuffled. The wallpaper each one shows now is in
    // playlistNow { name: { path, changed (ms) } }; the start script shows it.
    function playlist(name: string): var {
        return playlists.find(p => p.name === name) ?? null;
    }

    function playlistPath(name: string): string {
        const pl = playlist(name);
        const now = (config.playlistNow ?? {})[name]?.path ?? "";
        return pl && pl.items.includes(now) ? now : (pl?.items[0] ?? "");
    }

    function screenPlaylists(assignments: var): var {
        return Object.values(assignments).filter(v => v.startsWith("playlist:")).map(v => v.slice(9));
    }

    function playingPlaylists(): var {
        return [...new Set([...screenPlaylists(activeScreens), ...(screensaverActive ? screenPlaylists(screensaverScreens) : [])])];
    }

    // Show item `path` of playlist `name` (restarts the renderer if it's shown)
    function setPlaylistItem(name: string, path: string): void {
        patch({
            playlistNow: Object.assign({}, config.playlistNow ?? {}, {
                [name]: {
                    path,
                    changed: Date.now()
                }
            })
        });
        if (screenPlaylists(activeScreens).includes(name))
            restartTimer.restart();
    }

    // The next one: in order, or a random other one
    function nextInPlaylist(name: string): void {
        const pl = playlist(name);
        if (!pl || !pl.items.length)
            return;
        const items = pl.items.filter(i => wallpapers.length === 0 || wallpapers.some(w => w.path === i));
        if (!items.length)
            return;
        const cur = items.indexOf(playlistPath(name));
        let next;
        if (pl.order === "random" && items.length > 1) {
            do
                next = Math.floor(Math.random() * items.length);
            while (next === cur);
        } else {
            next = (cur + 1) % items.length;
        }
        setPlaylistItem(name, items[next]);
    }

    // Which item the clock picks (time of day: the day split between them;
    // day of week: one per weekday, Monday first), or -1
    function scheduledIndex(pl: var): int {
        const n = pl.items.length;
        if (!n)
            return -1;
        const d = new Date();
        if (pl.mode === "timeofday")
            return Math.min(n - 1, Math.floor((d.getHours() * 60 + d.getMinutes()) / (1440 / n)));
        if (pl.mode === "weekday")
            return ((d.getDay() + 6) % 7) % n;
        return -1;
    }

    // Every 30 s (and at start): change what's due
    function tickPlaylists(): void {
        for (const name of playingPlaylists()) {
            const pl = playlist(name);
            if (!pl)
                continue;
            if (paused && !pl.whilePaused)
                continue;
            const mode = pl.mode ?? "timer";
            if (mode === "timer") {
                const changed = (config.playlistNow ?? {})[name]?.changed ?? 0;
                if (Date.now() - changed >= Math.max(1, pl.delay ?? 30) * 60000)
                    nextInPlaylist(name);
            } else if (mode === "timeofday" || mode === "weekday") {
                const i = scheduledIndex(pl);
                if (i >= 0 && pl.items[i] !== playlistPath(name))
                    setPlaylistItem(name, pl.items[i]);
            }
        }
    }

    // A playlist put on a screen: from its first wallpaper when it says so
    // (or the clock's, for time of day / day of week)
    function startPlaylist(name: string): void {
        const pl = playlist(name);
        if (!pl)
            return;
        const i = scheduledIndex(pl);
        if (i >= 0)
            setPlaylistItem(name, pl.items[i]);
        else if (pl.beginFirst || !(config.playlistNow ?? {})[name])
            setPlaylistItem(name, pl.items[0]);
        else
            setPlaylistItem(name, playlistPath(name)); // its timer starts again
    }

    // "When logging in": the next one once per boot
    function loginPlaylists(): void {
        if (!crashProtectionActive && setting("startAtLogin", true)
            && playingPlaylists().some(name => (playlist(name)?.mode ?? "timer") === "login"))
            bootProc.running = true;
    }

    function savePlaylist(pl: var, oldName: string): void {
        const list = playlists.filter(p => p.name !== (oldName || pl.name));
        list.push(pl);
        list.sort((a, b) => a.name.localeCompare(b.name));
        patch({
            playlists: list
        });
        // A playing one changed (or was renamed): show the new version
        const playing = Object.entries(screens).filter(([, v]) => v === `playlist:${oldName || pl.name}`);
        if (playing.length) {
            const s = Object.assign({}, screens);
            for (const [k] of playing)
                s[k] = `playlist:${pl.name}`;
            patch({
                screens: s
            });
            restartTimer.restart();
        }
    }

    function deletePlaylist(name: string): void {
        patch({
            playlists: playlists.filter(p => p.name !== name)
        });
        for (const [k, v] of Object.entries(screens))
            if (v === `playlist:${name}`)
                stopScreen(k);
    }

    function refresh(): void {
        if (!scanProc.running)
            scanProc.running = true;
        if (!statusProc.running)
            statusProc.running = true;
    }

    function rescan(): void {
        if (!scanProc.running)
            scanProc.running = true;
    }

    function checkEngineUpdate(): void {
        latestProc.running = true;
    }

    // Try every untested wallpaper (or all, `again`) in the renderer
    function testAll(again: bool): void {
        const paths = wallpapers.filter(w => again || !(config.compat ?? {})[w.path]?.grade).map(w => w.path);
        if (!paths.length)
            return;
        testDone = 0;
        testTotal = paths.length;
        testProc.command = ["python3", "-I", scanner, "test", ...paths];
        testProc.running = true;
    }

    function stopTests(): void {
        testProc.running = false;
    }

    // Settings windows open: the Workshop's first page is fetched when the first
    // one opens (ready by the time it's visited), and the Workshop cache is
    // cleared when the last one closes
    property int settingsOpen
    property string workshopKey
    property bool loginChecked

    function settingsOpened(): void {
        settingsOpen++;
        // After the window has opened (its first frames shouldn't wait on this)
        if (settingsOpen === 1)
            warmTimer.restart();
    }

    function warmWorkshop(): void {
        if (settingsOpen > 0)
            loadWorkshop({
                sort: "trend",
                days: 7,
                page: 1,
                search: "",
                tags: [],
                mature: setting("showMature", false)
            });
    }

    function settingsClosed(): void {
        settingsOpen = Math.max(0, settingsOpen - 1);
        if (settingsOpen > 0)
            return;
        workshopProc.running = false;
        workshopKey = "";
        workshopPage = {
            items: []
        };
        workshopItem = null;
        Quickshell.execDetached(["rm", "-rf", `${Paths.cache}/workshop`]);
    }

    // q: { sort (trend/toprated/recent/updated/subscribed), days, page, search, tags[], mature }
    function loadWorkshop(q: var): void {
        // The same page already loading or shown (e.g. fetched as the settings opened)
        const key = JSON.stringify([q.sort ?? "trend", q.days ?? 7, q.page ?? 1, q.search ?? "", q.tags ?? [], !!q.mature]);
        if (key === workshopKey && (workshopProc.running || (workshopPage.items ?? []).length > 0))
            return;
        workshopKey = key;
        const cmd = ["python3", "-I", scanner, "workshop", "--sort", q.sort ?? "trend", "--days", String(q.days ?? 7), "--page", String(q.page ?? 1)];
        if (q.search)
            cmd.push("--search", q.search);
        for (const t of q.tags ?? [])
            cmd.push("--tag", t);
        if (q.mature)
            cmd.push("--mature");
        workshopProc.running = false;
        workshopProc.command = cmd;
        workshopLoading = true;
        workshopProc.running = true;
    }

    function steamStatus(): void {
        steamStatusProc.running = false;
        steamStatusProc.running = true;
    }

    function steamStartLogin(): void {
        steamLogin = {
            state: "starting"
        };
        steamLoginProc.running = false;
        steamLoginProc.running = true;
    }

    function steamCancelLogin(): void {
        steamLoginProc.running = false;
        steamLogin = null;
    }

    function steamLogout(): void {
        Quickshell.execDetached(["python3", "-I", steamHelper, "logout"]);
        steamSignedIn = false;
        steamAccount = "";
    }

    function steamSubscribe(id: string, on: bool): void {
        steamError = "";
        steamSubProc.item = id;
        steamSubProc.on = on;
        steamSubProc.command = ["python3", "-I", steamHelper, on ? "subscribe" : "unsubscribe", id];
        steamSubProc.running = true;
    }

    // Subscribe: on the Steam account (when signed in) and download it into
    // the own library (no Wallpaper Engine or Steam client needed)
    function getWallpaper(id: string): void {
        if (steamSignedIn)
            steamSubscribe(id, true);
        download = {
            id,
            state: "starting"
        };
        downloadProc.running = false;
        downloadProc.command = ["python3", "-I", steamHelper, "download", id];
        downloadProc.running = true;
    }

    function cancelDownload(): void {
        updateQueue = [];
        downloadProc.running = false;
        download = null;
    }

    function checkWorkshopUpdates(): void {
        if (workshopUpdatesProc.running)
            return;
        checkingWorkshopUpdates = true;
        workshopUpdatesError = "";
        workshopUpdatesProc.running = true;
    }

    function updateWallpaper(id: string): void {
        if (!id)
            return;
        getWallpaper(id);
    }

    function updateAllWallpapers(): void {
        const ids = workshopUpdates.map(u => String(u.id)).filter(id => id);
        if (!ids.length)
            return;
        updateFailures = [];
        updateQueue = ids.slice(1);
        getWallpaper(ids[0]);
    }

    // The next one of "Update all", after one finished or failed
    function nextUpdate(): void {
        if (updateQueue.length === 0)
            return;
        const nextId = updateQueue[0];
        updateQueue = updateQueue.slice(1);
        Qt.callLater(() => root.getWallpaper(nextId));
    }

    // A wallpaper folder that was just replaced: if a screen shows it, the
    // renderer restarts so it loads the new files (not the deleted old ones)
    function reloadIfShown(id: string): void {
        if (Object.values(screens).some(p => String(p).split("/").pop() === String(id)))
            restartTimer.restart();
    }

    // Unsubscribe: off the Steam account and out of the library
    function removeWallpaper(id: string): void {
        if (steamSignedIn)
            steamSubscribe(id, false);
        removeProc.command = ["python3", "-I", steamHelper, "remove", id];
        removeProc.running = true;
    }

    function loadWorkshopItem(id: string): void {
        workshopItem = null;
        workshopItemLoading = true;
        workshopItemProc.running = false;
        workshopItemProc.command = ["python3", "-I", scanner, "workshop-item", id];
        workshopItemProc.running = true;
    }

    // In Steam: the item's page, where it's subscribed to (Steam downloads it)
    function openInSteam(id: string): void {
        Quickshell.execDetached(["xdg-open", `steam://url/CommunityFilePage/${id}`]);
    }

    // The library is read once at start (a fraction of a second): the current
    // wallpaper's name and preview show without opening the page first
    Component.onCompleted: refresh()

    onDefaultAudioOutputChanged: {
        if (!defaultAudioOutput)
            return;
        const changed = previousAudioOutput && previousAudioOutput !== defaultAudioOutput;
        previousAudioOutput = defaultAudioOutput;
        if (changed && running && current && setting("reloadOnAudioOutputChange", true))
            restartTimer.restart();
    }

    Process {
        id: sleepMonitor

        running: root.running && !!root.current && root.setting("restartAfterSleep", false)
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                // logind sends true before sleeping and false after resuming.
                if (sleepMonitor.running && root.ruleAction !== "stop"
                    && line.trim() === "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)")
                    restartTimer.restart();
            }
        }
    }

    // Changes come in bursts (sliders): restart the renderer once after them
    Timer {
        id: restartTimer

        interval: 150
        onTriggered: {
            if (root.ruleAction === "stop")
                return;
            if (startProc.running) {
                startProc.again = true;
                root.runScript("cancel-handoff");
            } else {
                root.launchRenderer();
            }
        }
    }

    // A wallpaper applied: is it still running a few seconds after its start?
    property bool checkPending

    // The start script (stops the old renderer, up to 2 s, then starts); the
    // "does it work" check counts from when it's done, not from the click
    Process {
        id: startProc

        property bool again
        property var selection

        environment: ({
            LIVE_WALLPAPER_RULE_SELECTION: root.ruleSelection ? JSON.stringify(root.ruleSelection) : "",
            LIVE_WALLPAPER_TRANSITION_ID: root.switchingWallpaper?.id ?? ""
        })
        command: ["sh", "-c", `s=$(command -v live-wallpaper || echo '${root.scriptBin}'); exec "$s" start`]
        onExited: code => {
            if (code === 0)
                root.presentedScreens = selection;
            else
                root.switchingWallpaper = null;
            if (again && root.ruleAction !== "stop") {
                again = false;
                root.launchRenderer();
                return;
            }
            again = false;
            if (code === 0) {
                runningTimer.restart();
                if (root.ruleAction !== "run")
                    root.evaluateRules(true);
            }
            if (root.checkPending) {
                root.checkPending = false;
                if (code === 0)
                    checkTimer.restart();
                else
                    Quickshell.execDetached(["notify-send", "-a", "Live wallpaper", Tr.tr("Could not load the selected wallpaper")]);
            }
        }
    }

    // A few seconds after applying: still running? If not, the wallpaper
    // doesn't work with the renderer: say so, and remember it
    Timer {
        id: checkTimer

        interval: 4000
        onTriggered: checkProc.running = true
    }

    Timer {
        id: runningTimer

        interval: 800
        onTriggered: runningProc.running = true
    }

    Timer {
        running: (root.automaticPlaybackActive || root.screensaverActive) && root.playingPlaylists().length > 0
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: root.tickPlaylists()
    }

    Timer {
        id: warmTimer

        interval: 800
        onTriggered: root.warmWorkshop()
    }

    // The playback rules, checked every second while a live wallpaper is on and rules are active
    Timer {
        running: root.automaticPlaybackActive && Object.keys(root.screens).length > 0 && (root.hasActiveRules || root.ruleAction !== "run" || root.coverSupported)
        repeat: true
        interval: 1000
        onTriggered: {
            if (root.readsAudioRules)
                ruleAudioProc.running = true;
            else
                root.audioRuleStreams = [];
            if (root.playbackRules.displayAsleep !== "run")
                ruleDisplaysProc.running = true;
            else {
                root.wallpaperDisplaysAsleep = false;
                root.sleepingOutputs = [];
            }
            root.evaluateRules(false);
        }
        onRunningChanged: if (!running) {
            root.ruleAction = "run";
            root.ruleReason = "";
            root.rulePausePending = false;
            root.ruleSelection = null;
        }
    }

    Process {
        id: ruleAudioProc
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.audioRuleStreams = JSON.parse(text).filter(s => !s.corked && !s.mute).map(s => {
                        const props = s.properties ?? {};
                        const name = props["application.name"] ?? Tr.tr("An app");
                        return { name, identity: [name, props["application.process.binary"], props["application.id"]].join(" ") };
                    }).filter(s => !s.identity.toLowerCase().includes("wallpaperengine"));
                } catch (e) { root.audioRuleStreams = []; }
            }
        }
    }

    Process {
        id: ruleDisplaysProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const displays = JSON.parse(text).filter(m => root.activeScreens["*"] || root.activeScreens[m.name]);
                    root.sleepingOutputs = displays.filter(m => m.dpmsStatus === false).map(m => m.name);
                    root.wallpaperDisplaysAsleep = displays.length > 0 && root.sleepingOutputs.length === displays.length;
                } catch (e) {
                    root.wallpaperDisplaysAsleep = false;
                    root.sleepingOutputs = [];
                }
            }
        }
    }

    // This boot's id: "when logging in" playlists change once per boot
    Process {
        id: bootProc

        command: ["cat", "/proc/sys/kernel/random/boot_id"]
        stdout: StdioCollector {
            onStreamFinished: {
                const boot = text.trim();
                if (root.crashProtectionActive || !root.setting("startAtLogin", true) || !boot
                    || boot === root.setting("playlistBoot", ""))
                    return;
                root.setQuiet("playlistBoot", boot);
                for (const name of root.playingPlaylists())
                    if ((root.playlist(name)?.mode ?? "timer") === "login")
                        root.nextInPlaylist(name);
            }
        }
    }

    Process {
        id: scanProc

        command: ["env", `LIVE_WALLPAPER_ASSETS=${root.setting("assetsDir", "")}`, "python3", "-I", root.scanner, ...[].concat(...Array.from(root.setting("extraFolders", [])).map(d => ["--extra", d]))]
        onRunningChanged: root.scanning = running
        stdout: StdioCollector {
            onStreamFinished: {
                // Unchanged (the usual rescan): keep the list, so pages showing
                // it don't rebuild every card
                if (text !== root.lastScan) {
                    root.lastScan = text;
                    try {
                        root.wallpapers = JSON.parse(text);
                        root.migratePaths();
                    } catch (e) {
                        root.wallpapers = [];
                    }
                }
                if (root.pendingRandom && root.wallpapers.length) {
                    root.pendingRandom = false;
                    root.random();
                }
            }
        }
    }

    Process {
        id: statusProc

        command: ["sh", "-c", `(command -v live-wallpaper >/dev/null || [ -x '${root.scriptBin}' ]) && echo script; command -v linux-wallpaperengine >/dev/null && echo engine; (pacman -Q linux-wallpaperengine-nyks-git 2>/dev/null || pacman -Q linux-wallpaperengine-git 2>/dev/null) | cut -d' ' -f2; p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ] && { [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] || tr "\\0" "\\n" < /proc/$p/environ 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"; } && echo running; echo "assets=$(python3 -I '${root.scanner}' assets)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.hasScript = lines.includes("script");
                root.hasEngine = lines.includes("engine");
                root.running = lines.includes("running");
                root.engineVersion = lines.find(l => /^r\d+\./.test(l)) ?? "";
                root.assetsDetected = (lines.find(l => l.startsWith("assets=")) ?? "").slice(7);
            }
        }
    }

    // Watchdog: the renderer this shell saw drawing is gone although nothing stopped it (a
    // crash, or something else killing it): noted in live-wallpaper/events.log and started
    // again. Only after it was seen running here, so a test session never starts one.
    property bool seenRunning
    property bool waitingAfterCrash
    property int missing

    onRunningChanged: {
        // (a new renderer starts drawing in full: covered is sent again if it still is)
        coverSent = false;
        if (running) {
            publishedOutputPlayback = "";
            waitingAfterCrash = false;
            seenRunning = true;
            if (!presentedScreens)
                presentedScreens = selectedWallpapers();
            Qt.callLater(() => evaluateRules(true));
        }
    }

    Timer {
        running: root.seenRunning && Object.keys(root.screens).length > 0 && root.ruleAction !== "stop"
        repeat: true
        interval: 10000
        onTriggered: if (!watchProc.running)
            watchProc.running = true
    }

    Process {
        id: watchProc

        command: ["sh", "-c", `p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] || exit 2; [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ] && { [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] || tr "\\0" "\\n" < /proc/$p/environ 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"; }`]
        onExited: code => {
            if (code === 0 || startProc.running || restartTimer.running || Object.keys(root.screens).length === 0 || root.ruleAction === "stop") {
                root.missing = 0;
                return;
            }
            if (code === 2) {
                root.missing = 0;
                root.running = false;
                root.seenRunning = false;
                return;
            }
            // Twice in a row (20 s): not a restart in progress
            if (++root.missing < 2)
                return;
            root.missing = 0;
            const protect = root.setting("protectAfterCrash", false);
            if (protect)
                crashHold.setText(JSON.stringify(root.config.screens ?? {}));
            const restart = !protect && root.setting("restartAfterCrash", true);
            const action = protect ? "crash protection held the wallpaper selection"
                : restart ? "restart requested by the shell" : "automatic restart disabled";
            Quickshell.execDetached(["sh", "-c", `d="\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper"; c=$(coredumpctl -q --no-pager --since=-2min list linux-wallpaperengine 2>/dev/null | tail -1); printf '%s gone without a stop%s: %s\\n' "$(date '+%F %T')" "\${c:+ (crashed: $c)}" "$1" >> "$d/events.log"`, "sh", action]);
            root.running = false;
            if (restart)
                restartTimer.restart();
            else {
                root.waitingAfterCrash = true;
                root.seenRunning = false;
            }
        }
    }

    Process {
        id: runningProc

        command: ["sh", "-c", `p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ] && { [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] || tr "\\0" "\\n" < /proc/$p/environ 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"; }`]
        onExited: code => root.running = code === 0
    }

    Process {
        id: checkProc

        command: ["sh", "-c", `p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ] && { [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ] || tr "\\0" "\\n" < /proc/$p/environ 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"; } && echo ok || tail -5 "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/log"`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.running = text.trim() === "ok";
                if (root.running)
                    root.randomTries = 0;
                if (root.running || !root.current)
                    return;
                const why = (text.trim().split("\n").pop() || "The renderer stopped").replace(/\.? Use \S*linux-wallpaperengine --help.*$/, "");
                if (root.current.startsWith("playlist:")) {
                    Quickshell.execDetached(["notify-send", "-a", "Live wallpaper", "Live wallpaper", `The playlist didn't start: ${why}`]);
                    return;
                }
                const all = Object.assign({}, root.config.compat ?? {});
                all[root.current] = Object.assign({}, all[root.current] ?? {}, {
                    grade: "broken",
                    errors: [why]
                });
                root.patch({
                    compat: all
                });
                if (root.randomPick && root.randomTries < 3) {
                    root.randomTries++;
                    root.random();
                    return;
                }
                root.randomTries = 0;
                Quickshell.execDetached(["notify-send", "-a", "Live wallpaper", "Live wallpaper", `${root.currentInfo?.title ?? "This wallpaper"} doesn't work with linux-wallpaperengine`]);
            }
        }
    }

    // One JSON line per tested wallpaper
    Process {
        id: testProc

        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line);
                    const all = Object.assign({}, root.config.compat ?? {});
                    all[r.path] = Object.assign({}, all[r.path] ?? {}, {
                        grade: r.grade,
                        errors: r.errors
                    });
                    root.patch({
                        compat: all
                    });
                    root.testDone++;
                } catch (e) {}
            }
        }
    }

    // Lines: the cached page at once, then Steam's (when it changed)
    Process {
        id: workshopProc

        onRunningChanged: root.workshopLoading = running && !root.workshopPage.cached
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.workshopPage = JSON.parse(line);
                    if ((root.workshopPage.tagGroups ?? []).length > 0)
                        root.workshopTagGroups = root.workshopPage.tagGroups;
                    // A cached page shows as loaded; Steam's copy replaces it quietly
                    root.workshopLoading = false;
                } catch (e) {
                    root.workshopPage = {
                        items: [],
                        error: "No answer from the Workshop"
                    };
                }
            }
        }
    }

    Process {
        id: steamStatusProc

        command: ["python3", "-I", root.steamHelper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const st = JSON.parse(text);
                    root.steamSignedIn = st.signedIn;
                    root.steamAccount = st.account ?? "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: steamLoginProc

        command: ["python3", "-I", root.steamHelper, "login"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const st = JSON.parse(line);
                    root.steamLogin = st;
                    if (st.state === "done") {
                        root.steamSignedIn = true;
                        root.steamAccount = st.account ?? "";
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: steamSubProc

        property string item
        property bool on

        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try {
                    r = JSON.parse(text);
                } catch (e) {
                    r = {
                        error: "No answer"
                    };
                }
                if (r.ok) {
                    if (steamSubProc.on)
                        root.steamPending = root.steamPending.concat([steamSubProc.item]);
                    else
                        root.steamPending = root.steamPending.filter(x => x !== steamSubProc.item);
                    // Steam removes an unsubscribed one's folder soon after
                    root.refresh();
                } else {
                    root.steamError = r.error ?? "";
                    if (r.signin)
                        root.steamSignedIn = false;
                }
            }
        }
    }

    Process {
        id: downloadProc

        // Ended without saying done or error (it crashed): the queue goes on too
        onExited: {
            // An earlier run stopped by the next download starting: not this one
            if (running)
                return;
            const st = root.download?.state ?? "";
            if (root.download && st !== "done" && st !== "error") {
                root.download = Object.assign({}, root.download, {
                    state: "error",
                    error: Tr.tr("The download stopped")
                });
                if (root.updateQueue.length > 0)
                    root.updateFailures = root.updateFailures.concat([String(root.download.id)]);
                root.nextUpdate();
            }
        }

        stdout: SplitParser {
            onRead: line => {
                try {
                    const st = JSON.parse(line);
                    if (st.state === "log")
                        return;
                    root.download = Object.assign({}, root.download, st);
                    if (st.state === "done") {
                        const doneId = root.download.id;
                        root.steamPending = root.steamPending.filter(x => x !== doneId);
                        root.workshopUpdates = root.workshopUpdates.filter(u => String(u.id) !== String(doneId));
                        root.refresh();
                        root.reloadIfShown(doneId);
                        root.nextUpdate();
                    } else if (st.state === "error") {
                        // One failed: noted, and "Update all" goes on with the rest
                        // (it used to wait for a "done" that never came)
                        if (root.updateQueue.length > 0 || root.updateFailures.length > 0)
                            root.updateFailures = root.updateFailures.concat([String(root.download.id)]);
                        root.nextUpdate();
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: workshopUpdatesProc

        command: ["python3", "-I", root.scanner, "workshop-updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checkingWorkshopUpdates = false;
                try {
                    const res = JSON.parse(text);
                    root.workshopUpdates = res.updates ?? [];
                    root.workshopUpdatesError = res.error ?? "";
                } catch (e) {
                    root.workshopUpdatesError = Tr.tr("Could not check for Workshop updates");
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.checkingWorkshopUpdates = false;
        }
    }

    Process {
        id: removeProc

        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    Process {
        id: workshopItemProc

        onRunningChanged: if (!running) root.workshopItemLoading = false
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.workshopItem = JSON.parse(line).items?.[0] ?? null;
                    root.workshopItemLoading = false;
                } catch (e) {}
            }
        }
    }

    // The newest commit of the local/private renderer fork
    Process {
        id: latestProc

        command: ["sh", "-c", "git -C \"$HOME/hyprland-plugins/linux-wallpaperengine\" rev-parse --short=7 HEAD 2>/dev/null || git ls-remote https://github.com/Nyks45/linux-wallpaperengine.git HEAD 2>/dev/null | cut -c1-7"]
        stdout: StdioCollector {
            onStreamFinished: root.engineLatest = text.trim().slice(0, 7)
        }
    }

    FileView {
        id: file

        path: root.configPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.config = JSON.parse(text());
            } catch (e) {
                root.config = {};
            }
            // Once per shell start: "when logging in" playlists
            if (!root.loginChecked) {
                root.loginChecked = true;
                root.loginPlaylists();
            }
        }
        // None yet: take over what the Linux Wallpaper Engine GUI had (its
        // wallpapers per screen, settings, per-wallpaper overrides, grades)
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                importProc.running = true;
        }
    }

    Process {
        id: importProc

        command: ["python3", "-I", "-c", `
import json, os
d = os.path.expanduser("~/.config/Linux Wallpaper Engine")
def load(n):
    try:
        return json.load(open(os.path.join(d, n), encoding="utf-8"))
    except Exception:
        return {}
active, settings, over = load("active-wallpapers.json"), load("settings.json"), load("wallpaper-overrides.json")
c = {"screens": {}, "overrides": {}, "compat": {}, "history": active.get("appliedHistory") or {}}
for screen, w in (active.get("activeWallpapers") or {}).items():
    if w.get("backgroundId"):
        c["screens"][w.get("screen") or screen] = w["backgroundId"]
for key in ("fps", "postProcessing", "volume", "silent", "noAutomute", "audioProcessing", "disableMouse", "disableParallax", "disableParticles", "pauseOnFullscreen", "assetsDir"):
    if settings.get(key) is not None:
        c[key] = settings[key]
if settings.get("defaultScaling"):
    c["scaling"] = settings["defaultScaling"]
if settings.get("sortBy") in ("name", "recent"):
    c["sortBy"] = settings["sortBy"]
for path, o in (over.get("overrides") or {}).items():
    e = {k: o[k] for k in ("scaling", "volume", "audioProcessing", "disableMouse", "disableParallax", "disableParticles") if o.get(k) is not None}
    if o.get("customProperties"):
        e["properties"] = o["customProperties"]
    if e:
        c["overrides"][path] = e
    if o.get("compatibility") and o["compatibility"] != "unknown":
        c["compat"][path] = {"grade": o["compatibility"], "errors": o.get("autoErrors") or []}
print(json.dumps(c))
`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.save(JSON.parse(text));
                } catch (e) {}
            }
        }
    }
}
