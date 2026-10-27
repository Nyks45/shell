pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

// The desktop folder behind the desktop icons: adding apps to it, opening and
// trashing what's in it, and where each icon was placed.
Singleton {
    id: root

    readonly property string dir: Paths.desktop
    // File name -> { col, row } for icons the user moved
    property var positions: ({})
    // Trashed from the desktop in the last 5 minutes, newest last ({ path,
    // name, position, time }): Ctrl+Z puts them back
    property var recentlyTrashed: []
    readonly property int undoWindow: 5 * 60 * 1000

    // Back from the trash: the newest .trashinfo for that path (XDG trash spec),
    // unless something took its place meanwhile
    readonly property string restoreScript: ["import glob, os, shutil, sys, urllib.parse", "orig = sys.argv[1]", "base = os.path.join(os.environ.get('XDG_DATA_HOME') or os.path.expanduser('~/.local/share'), 'Trash')", "best = None", "for info in glob.glob(os.path.join(base, 'info', '*.trashinfo')):", "    try:", "        lines = open(info).read().splitlines()", "    except OSError:", "        continue", "    path = next((urllib.parse.unquote(l[5:]) for l in lines if l.startswith('Path=')), None)", "    date = next((l[13:] for l in lines if l.startswith('DeletionDate=')), '')", "    if path == orig and (best is None or date > best[1]):", "        best = (info, date)", "if best and not os.path.exists(orig):", "    name = os.path.basename(best[0])[:-len('.trashinfo')]", "    shutil.move(os.path.join(base, 'files', name), orig)", "    os.remove(best[0])"].join("\n")

    // A launcher for `app` on the desktop (like Windows' "Send to desktop")
    function addApp(app: DesktopEntry): void {
        if (!app)
            return;
        const lines = ["[Desktop Entry]", "Type=Application", `Name=${app.name}`, `Exec=${app.execString || app.command.join(" ")}`, `Icon=${app.icon}`];
        if (app.comment)
            lines.push(`Comment=${app.comment}`);
        if (app.runInTerminal)
            lines.push("Terminal=true");
        if (app.workingDirectory)
            lines.push(`Path=${app.workingDirectory}`);
        const file = `${dir}/${app.id}.desktop`;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s\\n' \"$2\" > \"$3\" && chmod +x \"$3\"", "sh", dir, lines.join("\n"), file]);
    }

    // Apps run (gio handles Exec placeholders and Terminal=true), folders open
    // in the file manager, other files in their default app
    function open(path: string, isDir: bool): void {
        // The Trash: its own location with gvfs (restoring works there), else
        // just its folder
        if (path === "trash:///") {
            Quickshell.execDetached(["sh", "-c", "if [ -e /usr/lib/gvfsd-trash ] || [ -e /usr/lib/gvfs/gvfsd-trash ]; then exec \"$@\" trash:///; else exec \"$@\" \"${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files\"; fi", "sh", ...GlobalConfig.general.apps.explorer]);
            return;
        }
        if (path.endsWith(".desktop"))
            Quickshell.execDetached(["gio", "launch", path]);
        else if (isDir)
            Quickshell.execDetached([...GlobalConfig.general.apps.explorer, path]);
        else
            Quickshell.execDetached(["xdg-open", path]);
    }

    function trash(path: string): void {
        const name = path.split("/").pop();
        const now = Date.now();
        recentlyTrashed = [...recentlyTrashed.filter(t => now - t.time < undoWindow), {
                path,
                name,
                position: positions[name] ?? null,
                time: now
            }];
        forget(name);
        Quickshell.execDetached(["gio", "trash", path]);
    }

    // Ctrl+Z: the last thing trashed here, if it was within 5 minutes
    function undoTrash(): void {
        const now = Date.now();
        const fresh = recentlyTrashed.filter(t => now - t.time < undoWindow);
        const last = fresh.pop();
        recentlyTrashed = fresh;
        if (!last)
            return;
        if (last.position)
            setPosition(last.name, last.position.col, last.position.row);
        Quickshell.execDetached(["python3", "-c", restoreScript, last.path]);
    }

    // For good. gio needs gvfs for it; without, empty the trash folders (what
    // emptying means, per the XDG trash spec)
    function emptyTrash(): void {
        Quickshell.execDetached(["sh", "-c", "gio trash --empty 2>/dev/null || { T=\"${XDG_DATA_HOME:-$HOME/.local/share}/Trash\"; [ -d \"$T/files\" ] && find \"$T/files\" \"$T/info\" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; }"]);
    }

    function setPosition(name: string, col: int, row: int): void {
        positions = Object.assign({}, positions, {
            [name]: {
                col,
                row
            }
        });
        positionsFile.setText(JSON.stringify(positions));
    }

    function forget(name: string): void {
        const p = Object.assign({}, positions);
        delete p[name];
        positions = p;
        positionsFile.setText(JSON.stringify(positions));
    }

    FileView {
        id: positionsFile

        path: `${Paths.state}/desktop-icons.json`
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object")
                    root.positions = data;
            } catch (e) {}
        }
    }
}
