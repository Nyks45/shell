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

    // A workspace's apps: running ones in the order their first window opened,
    // then (if `withPinned`) pinned apps that aren't running there.
    function appsFor(wsId: int, withPinned: bool): var {
        const groups = new Map();
        for (const t of Hypr.toplevelsForWs(wsId, GlobalConfig.bar.workspaces.ignoredTags)) {
            const cls = t.lastIpcObject.class ?? "";
            const entry = DesktopEntries.heuristicLookup(cls);
            const key = entry?.id ?? cls;
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
        return [...groups.values()];
    }

    function isMinimized(t: HyprlandToplevel): bool {
        return t?.lastIpcObject.tags?.includes("minimized") ?? false;
    }

    function isActive(app: var): bool {
        return app.toplevels.some(t => t === Hyprland.activeToplevel && !isMinimized(t));
    }

    function allMinimized(app: var): bool {
        return app.toplevels.length > 0 && app.toplevels.every(t => isMinimized(t));
    }

    function hyprflow(fn: string, t: HyprlandToplevel): void {
        Hypr.extras.message(`eval hl.plugin.hyprflow.${fn}("address:0x${t.address}")`);
    }

    function close(t: HyprlandToplevel): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${t.address}" })` : `closewindow address:0x${t.address}`);
    }

    function launch(app: var): void {
        const entry = app?.entry ?? DesktopEntries.heuristicLookup(app?.cls ?? "");
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
