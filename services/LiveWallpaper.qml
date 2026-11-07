pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
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
    property bool paused
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
    property bool pendingRandom

    readonly property string configPath: `${Paths.config}/live-wallpaper.json`
    readonly property string scanner: `${Quickshell.shellDir}/assets/live-wallpaper-scan.py`
    readonly property var screens: config.screens ?? {}
    // The wallpaper on all screens (or the first screen's)
    readonly property string current: screens["*"] ?? Object.values(screens)[0] ?? ""
    readonly property var currentInfo: wallpapers.find(w => w.path === current) ?? null
    readonly property var playlists: config.playlists ?? []

    function setting(key: string, fallback: var): var {
        return config[key] ?? fallback;
    }

    function save(next: var): void {
        config = next;
        file.setText(JSON.stringify(next, null, 4) + "\n");
    }

    function patch(changes: var): void {
        save(Object.assign({}, config, changes));
    }

    // A playback setting: the renderer restarts with it
    function set(key: string, value: var): void {
        patch({
            [key]: value
        });
        if (current)
            restartTimer.restart();
    }

    // UI-only choices (sorting, filters): no restart
    function setQuiet(key: string, value: var): void {
        patch({
            [key]: value
        });
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
        patch(changes);
        // Caelestia's own wallpaper stays hidden under the live one (the script
        // still sets it, for the lock screen and the colours)
        GlobalConfig.background.wallpaperEnabled = false;
        paused = false;
        restartTimer.restart();
        checkTimer.restart();
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
            screens: {}
        });
        paused = false;
        Quickshell.execDetached(["live-wallpaper", "stop"]);
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
        paused = !paused;
        Quickshell.execDetached(["live-wallpaper", paused ? "pause" : "resume"]);
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

    // Playlists (Wallpaper Engine's format: the renderer rotates them itself)
    function savePlaylist(pl: var, oldName: string): void {
        const list = playlists.filter(p => p.name !== (oldName || pl.name));
        list.push(pl);
        list.sort((a, b) => a.name.localeCompare(b.name));
        patch({
            playlists: list
        });
        writePlaylists();
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
        writePlaylists();
        for (const [k, v] of Object.entries(screens))
            if (v === `playlist:${name}`)
                stopScreen(k);
    }

    function writePlaylists(): void {
        playlistTimer.restart();
    }

    function refresh(): void {
        scanProc.running = true;
        statusProc.running = true;
        runningTimer.restart();
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

    function settingsOpened(): void {
        settingsOpen++;
        if (settingsOpen === 1)
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
        downloadProc.running = false;
        download = null;
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

    // Changes come in bursts (sliders): restart the renderer once after them
    Timer {
        id: restartTimer

        interval: 500
        onTriggered: Quickshell.execDetached(["live-wallpaper", "start"])
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
        id: playlistTimer

        interval: 300
        onTriggered: Quickshell.execDetached(["env", `LIVE_WALLPAPER_ASSETS=${root.setting("assetsDir", "")}`, "python3", "-I", root.scanner, "playlists", root.configPath])
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

        command: ["sh", "-c", `command -v live-wallpaper >/dev/null && echo script; command -v linux-wallpaperengine >/dev/null && echo engine; pacman -Q linux-wallpaperengine-git 2>/dev/null | cut -d' ' -f2; p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ] && echo running; echo "assets=$(python3 -I '${root.scanner}' assets)"`]
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

    Process {
        id: runningProc

        command: ["sh", "-c", `p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ]`]
        onExited: code => root.running = code === 0
    }

    Process {
        id: checkProc

        command: ["sh", "-c", `p=$(cat "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/pid" 2>/dev/null); [ -n "$p" ] && [ "$(cat /proc/$p/comm 2>/dev/null)" = linux-wallpaper ] && echo ok || tail -5 "\${XDG_STATE_HOME:-$HOME/.local/state}/live-wallpaper/log"`]
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

        stdout: SplitParser {
            onRead: line => {
                try {
                    const st = JSON.parse(line);
                    if (st.state === "log")
                        return;
                    root.download = Object.assign({}, root.download, st);
                    if (st.state === "done") {
                        root.steamPending = root.steamPending.filter(x => x !== root.download.id);
                        root.refresh();
                    }
                } catch (e) {}
            }
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

    // The newest upstream commit of the renderer (the -git package builds it)
    Process {
        id: latestProc

        command: ["git", "ls-remote", "https://github.com/Almamu/linux-wallpaperengine.git", "HEAD"]
        stdout: StdioCollector {
            onStreamFinished: root.engineLatest = text.trim().slice(0, 7)
        }
    }

    FileView {
        id: file

        path: root.configPath
        printErrors: false
        blockAllReads: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.config = JSON.parse(text());
            } catch (e) {
                root.config = {};
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
