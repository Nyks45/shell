//@ pragma AppId caelestia-paint
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import qs.modules.paint

// Caelestia Paint: its own app (its own process, so a big picture or a crash can't affect the
// shell), one instance for all its windows. Started by assets/caelestia-paint:
//   caelestia-paint [FILE...]     open pictures (a new window each; nothing = a new picture)
//   caelestia-paint --clipboard   the picture on the clipboard as a new picture
// Unsaved work is kept in ~/.local/state/caelestia/paint/sessions until saved or discarded.
ShellRoot {
    id: app

    property list<var> windows: []
    property var prefs: ({})
    property var unsaved: []
    property var activeSessions: []
    readonly property string sessionsRoot: `${Paths.state}/paint/sessions`

    settings.watchFiles: false

    function create(props: var): var {
        const w = windowComp.createObject(app, Object.assign({
            app: app
        }, props));
        if (w)
            windows = [...windows, w];
        return w;
    }

    function open(path: string): void {
        if (path === "@clipboard") {
            const w = create({});
            w?.pasteAsNewHere();
            return;
        }
        create({
            source: path
        });
    }

    function newPicture(page: var): void {
        create({
            newPage: page
        });
    }

    function windowClosed(w: var): void {
        windows = windows.filter(x => x !== w);
        w.destroy();
        if (windows.length === 0)
            quitTimer.restart();
    }

    function newSessionDir(): string {
        const d = `${sessionsRoot}/${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
        activeSessions = [...activeSessions, d];
        return d;
    }

    function releaseSession(d: string): void {
        activeSessions = activeSessions.filter(x => x !== d);
    }

    function setPref(k: string, v: var): void {
        const n = Object.assign({}, prefs);
        n[k] = v;
        prefs = n;
        prefsSave.restart();
    }

    function restoreAll(from: var): void {
        const list = unsaved;
        unsaved = [];
        for (const s of list) {
            activeSessions = [...activeSessions, s.dir];
            create({
                restoreFrom: s
            });
        }
        // an empty window that asked for it has done its job
        if (from && from.untouched && !from.dirty) {
            from.forceClose = true;
            from.discardSession();
            from.close();
        }
    }

    function discardUnsaved(): void {
        for (const s of unsaved)
            Quickshell.execDetached(["rm", "-rf", s.dir]);
        unsaved = [];
    }

    Component.onCompleted: {
        try {
            prefs = JSON.parse(prefsFile.text() || "{}");
        } catch (e) {
            prefs = {};
        }
        const arg = Quickshell.env("CAELESTIA_PAINT_OPEN") ?? "";
        if (arg)
            for (const p of arg.split("\n").filter(x => x))
                open(p);
        else
            newPicture(null);
        scan.running = true;
    }

    Component {
        id: windowComp

        PaintWindow {}
    }

    Timer {
        id: quitTimer

        interval: 300
        onTriggered: if (app.windows.length === 0)
            Qt.quit()
    }

    FileView {
        id: prefsFile

        path: `${Paths.config}/paint.json`
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    Timer {
        id: prefsSave

        interval: 500
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", Paths.config]);
            prefsFile.setText(JSON.stringify(app.prefs, null, 2) + "\n");
        }
    }

    // unsaved pictures left by an earlier run (closed by a crash, a logout...)
    Process {
        id: scan

        command: ["sh", "-c", 'for f in "$1"/*/doc.json; do [ -f "$f" ] && printf "%s\\t%s\\n" "$(dirname "$f")" "$(tr -d "\\n" < "$f")"; done; exit 0', "sh", app.sessionsRoot]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const dir = line.slice(0, tab);
                    if (app.activeSessions.includes(dir))
                        continue;
                    try {
                        const st = JSON.parse(line.slice(tab + 1));
                        if (st.clean)
                            Quickshell.execDetached(["rm", "-rf", dir]);
                        else if (st.doc)
                            found.push({
                                dir: dir,
                                state: st
                            });
                    } catch (e) {}
                }
                app.unsaved = found;
            }
        }
    }

    IpcHandler {
        target: "paint"

        function open(path: string): void {
            app.open(path);
        }

        function blank(): void {
            app.newPicture(null);
        }

        function clipboard(): void {
            app.open("@clipboard");
        }

        function count(): int {
            return app.windows.length;
        }

        // the state of window `index` (0 = the first), as JSON
        function state(index: int): string {
            return app.windows[index]?.stateJson() ?? "{}";
        }

        function locate(index: int, query: string): string {
            return app.windows[index]?.locate(query) ?? "";
        }

        function unsavedCount(): int {
            return app.unsaved.length;
        }
    }
}
