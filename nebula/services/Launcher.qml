pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.utils
import qs.services as Shell
import qs.modules.launcher.services as ShellLauncher

// Nebula's Clover launcher, fed by the shell (launcher style "Nebula", Wallpaper & style > Nebula):
// - apps: the shell's apps without the hidden ones (Settings > Apps), pinned then recent first; started
//   the shell's way (terminal apps in the terminal, launch counts)
// - commands (">"): the shell's launcher actions (Settings > Launcher > Actions), in Nebula's
//   order, with Nebula's Record (the shell's recorder) and one Light/Dark toggle
// - pickers: Theme = the shell's colour schemes (previews from their colours), Variant = the
//   Material variants, Wallpaper = the shell's wallpapers, Calculator = qalc (Enter copies)
Singleton {
    id: root

    readonly property string directory: Paths.state + "/nebula"
    readonly property int appSlots: 8
    readonly property int commandSlots: 7
    readonly property int recentLimit: 20

    property string query: ""
    property string picker: ""
    readonly property bool wallpaperMode: picker === "wallpaper"
    readonly property bool themeMode: picker === "theme" || picker === "variant"
    readonly property bool calcMode: picker === "calc"
    readonly property bool commandMode: picker === "" && query.startsWith(">")
    readonly property string search: (commandMode ? query.slice(1) : query).trim().toLowerCase()
    readonly property int slots: commandMode ? commandSlots : appSlots
    readonly property string placeholder: wallpaperMode ? Tr.tr("Wallpapers") : picker === "theme" ? Tr.tr("Themes") : picker === "variant" ? Tr.tr("Variants") : calcMode ? Tr.tr("Calculate") : query === ">" ? Tr.tr("> Commands") : Tr.tr("Search")

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay && !Strings.testRegexList(GlobalConfig.launcher.hiddenApps, e.id)).sort((a, b) => a.name.localeCompare(b.name))

    // Nebula's order first; the rest of the shell's actions after
    readonly property var order: ["scheme", "settings", "lock", "sleep", "reboot", "shutdown", "logout", "record", "wallpaper", "mode"]

    readonly property var commands: {
        const dangerous = GlobalConfig.launcher.enableDangerousActions;
        const list = [];
        let mode = false;
        for (const a of GlobalConfig.launcher.actions.values) {
            if (!(a.enabled ?? true) || (!dangerous && a.dangerous))
                continue;
            const cmd = a.command ?? [];
            if (cmd.length === 0)
                continue;
            const item = {
                name: a.name ? Tr.trMarked(a.name) : Tr.trCtx("Unnamed", "launcher action with no name"),
                icon: a.icon ?? "help_outline",
                key: ""
            };
            if (cmd[0] === "autocomplete") {
                const pick = cmd[1] === "scheme" ? "theme" : cmd[1];
                if (!["theme", "variant", "wallpaper", "calc"].includes(pick))
                    continue;
                item.key = cmd[1];
                item.keepOpen = true;
                item.run = () => root.enter(pick);
            } else if (cmd[0] === "setMode") {
                // One toggle (as in Nebula): the mode that is not on now
                if (mode || (cmd[1] === "light") === Shell.Colours.currentLight)
                    continue;
                mode = true;
                item.key = "mode";
                item.run = () => Shell.Colours.setMode(cmd[1]);
            } else {
                const c = cmd.join(" ");
                item.key = c.includes("nexus") ? "settings" : c.includes("lock-session") ? "lock" : /suspend|hibernate/i.test(c) ? "sleep" : c === "reboot" ? "reboot" : c === "poweroff" ? "shutdown" : c === "logout" ? "logout" : "";
                item.run = () => {
                    if (!SessionManager.exec(cmd))
                        Quickshell.execDetached(cmd);
                };
            }
            list.push(item);
        }
        list.push({
            name: Shell.Recorder.running ? Tr.tr("Stop recording") : Tr.tr("Record"),
            icon: Shell.Recorder.running ? "stop_circle" : "screen_record",
            key: "record",
            run: () => Shell.Recorder.running ? Shell.Recorder.stop() : Shell.Recorder.start()
        });
        const rankOf = i => {
            const r = root.order.indexOf(i.key);
            return r < 0 ? root.order.length : r;
        };
        return list.map((i, n) => ({
                    i,
                    n
                })).sort((a, b) => rankOf(a.i) - rankOf(b.i) || a.n - b.n).map(x => x.i);
    }

    readonly property var wallpapers: Shell.Wallpapers.list.map(w => ({
                name: String(w.path).split("/").pop().replace(/\.[^.]+$/, ""),
                path: w.path
            }))
    readonly property string currentWallpaper: Shell.Wallpapers.actualCurrent

    // `scheme` is the key Nebula's ring looks things up by; `preview` its colours
    readonly property var themes: ShellLauncher.Schemes.list.map(s => ({
                name: s.flavour && s.flavour !== "default" ? `${s.name} ${s.flavour}` : s.name,
                scheme: `${s.name} ${s.flavour}`,
                schemeName: s.name,
                flavour: s.flavour,
                preview: root.previewOf(s.colours)
            }))
    readonly property var variants: ShellLauncher.M3Variants.list.map(v => ({
                name: v.name,
                scheme: `variant:${v.variant}`,
                variant: v.variant,
                icon: v.icon
            }))
    readonly property string currentTheme: picker === "variant" ? `variant:${ShellLauncher.Schemes.currentVariant}` : ShellLauncher.Schemes.currentScheme

    function previewOf(c: var): var {
        if (!c)
            return null;
        const hex = k => c[k] ? (String(c[k]).startsWith("#") ? c[k] : `#${c[k]}`) : undefined;
        return {
            primary: hex("primary"),
            secondary: hex("secondary"),
            tertiary: hex("tertiary"),
            primaryContainer: hex("primaryContainer") ?? hex("primary_container"),
            surface: hex("surfaceContainerHigh") ?? hex("surface_container_high")
        };
    }

    readonly property var calcResult: calcMode ? [
        {
            name: query.trim() === "" ? Tr.tr("Type a sum") : (Qalculator.result || Tr.tr("Calculating…")),
            icon: "calculate",
            run: () => {
                if (Qalculator.rawResult)
                    Quickshell.execDetached(["wl-copy", Qalculator.rawResult]);
            }
        }
    ] : []

    signal clearRequested

    function enter(pick: string): void {
        picker = pick;
        if (pick === "theme" || pick === "variant")
            ShellLauncher.Schemes.reload();
        clearRequested();
    }

    readonly property var results: {
        if (wallpaperMode)
            return rank(wallpapers, w => [w.name]);
        if (picker === "theme")
            return rank(themes, s => [s.name]);
        if (picker === "variant")
            return rank(variants, v => [v.name]);
        if (calcMode)
            return calcResult;
        if (commandMode)
            return rank(commands, c => [c.name]).slice(0, slots);
        if (search === "") {
            // Pinned in the launcher (Settings > Apps) first, then the recent ones
            const fav = apps.filter(e => Strings.testRegexList(GlobalConfig.launcher.favouriteApps, e.id));
            const recent = adapter.recent.map(id => apps.find(e => e.id === id)).filter(e => e && !fav.includes(e));
            const rest = apps.filter(e => !fav.includes(e) && !recent.includes(e));
            return fav.concat(recent, rest).slice(0, slots);
        }
        return rank(apps, e => [e.name, e.genericName, ...e.keywords]).slice(0, slots);
    }

    onQueryChanged: {
        if (calcMode && query.trim() !== "")
            Qalculator.evalAsync(query.trim());
    }

    function score(text) {
        const t = (text ?? "").toLowerCase();
        if (t === "" || search === "")
            return search === "" ? 1 : 0;
        if (t.startsWith(search))
            return 4;
        if (t.split(/[\s\-_]/).some(w => w.startsWith(search)))
            return 3;
        if (t.includes(search))
            return 2;
        return 0;
    }

    function rank(items, fields) {
        return items.map((item, i) => ({
                    item,
                    i,
                    s: Math.max(...fields(item).map(f => score(f)))
                })).filter(r => r.s > 0).sort((a, b) => b.s - a.s || a.i - b.i).map(r => r.item);
    }

    function clearRecent() {
        adapter.recent = [];
    }

    function open(screenName) {
        query = "";
        picker = "";
        const name = screenName ?? GlobalStates.focusedScreen();
        if (!GlobalStates.launcherOpen || GlobalStates.screen !== name) {
            GlobalStates.closeAll();
            GlobalStates.screen = name;
            GlobalStates.launcherOpen = true;
        }
    }

    function close() {
        GlobalStates.launcherOpen = false;
    }

    function toggle() {
        GlobalStates.launcherOpen ? close() : open();
    }

    function activate(item) {
        if (!item)
            return;
        if (wallpaperMode) {
            close();
            Shell.Wallpapers.setWallpaper(item.path);
            return;
        }
        if (picker === "theme") {
            close();
            Quickshell.execDetached(["caelestia", "scheme", "set", "-n", item.schemeName, "-f", item.flavour]);
            return;
        }
        if (picker === "variant") {
            close();
            Quickshell.execDetached(["caelestia", "scheme", "set", "-v", item.variant]);
            return;
        }
        if (calcMode || commandMode) {
            if (!item.keepOpen)
                close();
            item.run();
            return;
        }
        close();
        ShellLauncher.Apps.launch(item);
        adapter.recent = [item.id, ...adapter.recent.filter(id => id !== item.id)].slice(0, recentLimit);
    }

    property bool dirReady: false

    Process {
        running: true
        command: ["mkdir", "-p", root.directory]
        onExited: root.dirReady = true
    }

    FileView {
        path: root.dirReady ? root.directory + "/launcher.json" : ""
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property var recent: []
        }
    }

    Connections {
        function onFocusedWorkspaceChanged() {
            root.close();
        }
        function onFocusedMonitorChanged() {
            root.close();
        }

        target: Hyprland
    }

    IpcHandler {
        target: "nebulaLauncher"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }
}
