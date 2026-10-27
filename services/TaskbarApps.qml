pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia.Config
import qs.utils

// The taskbar built into the bar's workspaces: each workspace's windows as one
// item per app, pinned apps, and what clicking them does. Minimizing uses the
// hyprflow plugin (hl.plugin.hyprflow.*); windows it minimized carry the
// "minimized" tag.
Singleton {
    id: root

    // Pinned apps (desktop entry ids), kept in the state dir.
    property list<string> pinned: []
    // A taskbar right-click menu is open: the drawers take all input meanwhile
    // (the menu sits outside their normal input region; a click elsewhere
    // closes it).
    property bool menuOpen
    // When each app (key) first showed up, so the order stays put as windows
    // are raised, focused or closed (Hyprland's own list reorders).
    // (Mutated in place, never reassigned: appsFor() runs inside bindings.)
    readonly property var firstSeen: ({
            next: 0,
            keys: {}
        })

    function isPinned(id: string): bool {
        return pinned.includes(id);
    }

    function pin(id: string): void {
        if (!id || isPinned(id))
            return;
        pinned = [...pinned, id];
        pinsFile.setText(JSON.stringify(pinned));
    }

    function unpin(id: string): void {
        pinned = pinned.filter(p => p !== id);
        pinsFile.setText(JSON.stringify(pinned));
    }

    // A workspace's apps, in a stable order like Windows': pinned apps first
    // (in pin order, running or not, if `withPinned`), then the others in the
    // order they were first opened.
    // An app's key: its desktop entry, else its class. A window with no class
    // (some X11 programs) is an app of its own.
    function keyFor(t: HyprlandToplevel): string {
        const cls = t.lastIpcObject.class ?? "";
        return cls ? DesktopEntries.heuristicLookup(cls)?.id ?? cls : `window:${t.address}`;
    }

    function appsFor(wsId: int, withPinned: bool): var {
        const groups = new Map();
        // Hypr.toplevelsForWs() leaves out windows with no class: kept here.
        const ignored = GlobalConfig.bar.workspaces.ignoredTags;
        const shown = Hypr.toplevels.values.filter(t => t.workspace?.id === wsId && t.lastIpcObject.mapped && !(t.lastIpcObject.tags?.some(tag => ignored.includes(tag.replace(/\*$/, ""))) ?? false));
        for (const t of shown) {
            const cls = t.lastIpcObject.class ?? "";
            const entry = cls ? DesktopEntries.heuristicLookup(cls) : null;
            const key = keyFor(t);
            if (!groups.has(key))
                groups.set(key, {
                    key: key,
                    entry: entry,
                    cls: cls,
                    pinned: false,
                    toplevels: []
                });
            groups.get(key).toplevels.push(t);
        }
        for (const id of pinned) {
            if (groups.has(id)) {
                groups.get(id).pinned = true;
                continue;
            }
            const entry = withPinned ? DesktopEntries.byId(id) : null;
            if (entry)
                groups.set(id, {
                    key: id,
                    entry: entry,
                    cls: entry.id,
                    pinned: true,
                    toplevels: []
                });
        }
        const seen = firstSeen.keys;
        // Apps with no windows anywhere any more start over at the end.
        const running = new Set(Hypr.toplevels.values.map(t => keyFor(t)));
        for (const key of Object.keys(seen))
            if (!running.has(key))
                delete seen[key];
        for (const key of groups.keys())
            if (seen[key] === undefined)
                seen[key] = ++firstSeen.next;
        const pinIndex = key => {
            const i = pinned.indexOf(key);
            return i < 0 ? Infinity : i;
        };
        return [...groups.values()].sort((a, b) => {
            const pa = pinIndex(a.key), pb = pinIndex(b.key);
            if (pa !== pb)
                return pa < pb ? -1 : 1;
            return (seen[a.key] ?? 0) - (seen[b.key] ?? 0);
        });
    }

    // Minimized by hyprflow: tagged and actually hidden (a tag left on a shown
    // window, e.g. after hyprflow was unloaded, doesn't count).
    function isMinimized(t: HyprlandToplevel): bool {
        const ipc = t?.lastIpcObject;
        return (ipc?.tags?.includes("minimized") ?? false) && (ipc?.hidden ?? false);
    }

    function isActive(app: var): bool {
        return app.toplevels.some(t => t === Hyprland.activeToplevel && !isMinimized(t));
    }

    function allMinimized(app: var): bool {
        return app.toplevels.length > 0 && app.toplevels.every(t => isMinimized(t));
    }

    // hl.plugin.hyprflow.<fn>(window); without hyprflow, activating/restoring
    // falls back to a plain focus (so the taskbar always works).
    function hyprflow(fn: string, t: HyprlandToplevel): void {
        const sel = `address:0x${t.address}`;
        const fallback = fn === "activate" || fn === "restore" ? `hl.dispatch(hl.dsp.focus({ window = "${sel}" }))` : "";
        Hypr.extras.message(`eval local hf = hl.plugin and hl.plugin.hyprflow; if hf and hf.${fn} then hf.${fn}("${sel}") else ${fallback} end`);
    }

    function close(t: HyprlandToplevel): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${t.address}" })` : `closewindow address:0x${t.address}`);
    }

    function launch(app: var): void {
        const entry = app?.entry ?? (app?.cls ? DesktopEntries.heuristicLookup(app.cls) : null);
        if (!entry)
            return;
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    // The app's most recently used window.
    function recent(app: var): HyprlandToplevel {
        return [...app.toplevels].sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 1e9) - (b.lastIpcObject.focusHistoryID ?? 1e9))[0] ?? null;
    }

    // Like a taskbar: launch a pinned app; focus its window, minimize it when
    // it's focused, bring it back when minimized; with several windows, go on
    // to the next one.
    function click(app: var): void {
        const wins = app.toplevels;
        if (wins.length === 0) {
            launch(app);
            return;
        }
        const active = wins.indexOf(Hyprland.activeToplevel);
        if (wins.length === 1)
            hyprflow(active === 0 && !isMinimized(wins[0]) ? "minimize" : "activate", wins[0]);
        else if (active >= 0 && !isMinimized(wins[active]))
            hyprflow("activate", wins[(active + 1) % wins.length]);
        else
            hyprflow("activate", recent(app));
    }

    FileView {
        id: pinsFile

        path: `${Paths.state}/taskbar-pins.json`
        printErrors: false
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.pinned = list.filter(p => typeof p === "string");
            } catch (e) {}
        }
    }
}
