pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// How apps look, for the settings app's Fonts / App appearance /
// Accessibility pages: GTK settings (gsettings), Qt apps (qtengine, through
// assets/apply-app-look.py) and the icon theme (the caelestia CLI's cli.json,
// which re-applies it on every colour scheme change).
Singleton {
    id: root

    // gsettings values: "schema key" -> value (strings unquoted)
    property var gs: ({})
    // The settings app's choices for Qt apps and the icon theme (app-look.json)
    property var prefs: ({})
    property var cli: ({})
    property list<var> iconThemes: []
    property list<string> qtStyles: ["Fusion"]

    readonly property string prefsPath: `${Paths.config}/app-look.json`
    readonly property string cliPath: `${Paths.config}/cli.json`
    readonly property string qtPath: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/qtengine/config.json`
    readonly property string hookScript: `${Quickshell.shellDir}/assets/apply-app-look.py`

    // The icon theme set here, or "" for the CLI's default (Papirus, light/dark)
    readonly property string iconTheme: cli.theme?.iconTheme ?? ""

    function get(schema: string, key: string, fallback: var): var {
        return gs[`${schema} ${key}`] ?? fallback;
    }

    function set(schema: string, key: string, value: var): void {
        const next = Object.assign({}, gs);
        next[`${schema} ${key}`] = value;
        gs = next;
        // gsettings takes GVariant text: strings quoted, the rest as they are
        const text = typeof value === "string" ? `'${value.replace(/'/g, "\\'")}'` : String(value);
        Quickshell.execDetached(["gsettings", "set", schema, key, text]);
    }

    // "Adwaita Sans 11" -> { family, size }
    function parseFont(text: string): var {
        const m = String(text ?? "").match(/^(.*?)\s+(\d+(?:\.\d+)?)$/);
        return m ? {
            family: m[1],
            size: parseFloat(m[2])
        } : {
            family: text ?? "",
            size: 11
        };
    }

    function gtkFont(key: string): var {
        return parseFont(get("org.gnome.desktop.interface", key, ""));
    }

    function setGtkFont(key: string, family: string, size: real): void {
        set("org.gnome.desktop.interface", key, `${family} ${size}`);
    }

    function qt(key: string, fallback: var): var {
        return prefs.qt?.[key] ?? fallback;
    }

    function setQt(key: string, value: var): void {
        const qt = Object.assign({}, prefs.qt ?? {});
        qt[key] = value;
        savePrefs(Object.assign({}, prefs, {
            qt
        }));
    }

    // "" goes back to the CLI's default (Papirus-Dark / Papirus-Light)
    function setIconTheme(name: string): void {
        const theme = Object.assign({}, cli.theme ?? {});
        delete theme.iconThemeDark;
        delete theme.iconThemeLight;
        if (name)
            theme.iconTheme = name;
        else
            delete theme.iconTheme;
        saveCli(Object.assign({}, cli, {
            theme
        }));
        savePrefs(Object.assign({}, prefs, {
            iconTheme: name
        }));
        set("org.gnome.desktop.interface", "icon-theme", name || `Papirus-${Colours.light ? "Light" : "Dark"}`);
    }

    function savePrefs(next: var): void {
        prefs = next;
        prefsFile.setText(JSON.stringify(next, null, 4) + "\n");
        ensureHook();
        applyTimer.restart();
    }

    function saveCli(next: var): void {
        cli = next;
        cliFile.setText(JSON.stringify(next, null, 4) + "\n");
    }

    // The CLI runs the hook after every scheme change, so its rewrite of
    // qtengine's config keeps these choices
    function ensureHook(): void {
        const cmd = `python3 '${hookScript}'`;
        const hook = cli.theme?.postHook ?? "";
        if (hook.includes("apply-app-look.py"))
            return;
        const theme = Object.assign({}, cli.theme ?? {});
        theme.postHook = hook ? `${hook}; ${cmd}` : cmd;
        saveCli(Object.assign({}, cli, {
            theme
        }));
    }

    function refresh(): void {
        gsProc.running = true;
        iconProc.running = true;
        styleProc.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        id: applyTimer

        interval: 300
        onTriggered: Quickshell.execDetached(["python3", root.hookScript])
    }

    Process {
        id: gsProc

        command: ["sh", "-c", "for s in org.gnome.desktop.interface org.gnome.desktop.a11y.interface org.gnome.desktop.sound org.gnome.desktop.privacy org.gnome.desktop.wm.preferences; do gsettings list-recursively $s 2>/dev/null; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\S+)\s+(\S+)\s+(.*)$/);
                    if (!m)
                        continue;
                    let v = m[3].trim();
                    if (/^'.*'$/.test(v))
                        v = v.slice(1, -1);
                    else if (v === "true" || v === "false")
                        v = v === "true";
                    else if (/^(uint32 |int32 |double )?-?\d+(\.\d+)?$/.test(v))
                        v = parseFloat(v.replace(/^\w+ /, ""));
                    out[`${m[1]} ${m[2]}`] = v;
                }
                root.gs = out;
            }
        }
    }

    // Icon themes: folders with an index.theme listing icon Directories (cursor
    // themes have none); "name\tdisplay name" lines
    Process {
        id: iconProc

        command: ["python3", "-c", `
import configparser, os, pathlib
seen = {}
dirs = [pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")) / "icons", pathlib.Path.home() / ".icons", pathlib.Path("/usr/share/icons")]
for d in dirs:
    if not d.is_dir():
        continue
    for t in sorted(d.iterdir()):
        idx = t / "index.theme"
        if t.name in seen or t.name in ("hicolor", "default", "locolor") or not idx.is_file():
            continue
        c = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            c.read(idx, encoding="utf-8")
            sec = c["Icon Theme"]
        except Exception:
            continue
        if not sec.get("Directories", "").strip() or sec.get("Hidden", "false").lower() == "true":
            continue
        seen[t.name] = sec.get("Name", t.name)
for k, v in seen.items():
    print(k + "\\t" + v)
`]
        stdout: StdioCollector {
            onStreamFinished: root.iconThemes = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [name, display] = l.split("\t");
                    return {
                        name,
                        display
                    };
                }).sort((a, b) => a.display.localeCompare(b.display))
        }
    }

    // Qt widget styles installed as plugins (Fusion is built in)
    Process {
        id: styleProc

        command: ["sh", "-c", "ls /usr/lib/qt6/plugins/styles/ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = {
                    darkly6: "Darkly",
                    breeze6: "Breeze",
                    kvantum: "kvantum",
                    oxygen6: "Oxygen",
                    lightly6: "Lightly"
                };
                const styles = ["Fusion"];
                for (const f of text.split("\n")) {
                    const base = f.replace(/^lib/, "").replace(/\.so$/, "");
                    if (known[base])
                        styles.push(known[base]);
                }
                root.qtStyles = styles;
            }
        }
    }

    FileView {
        id: prefsFile

        path: root.prefsPath
        printErrors: false
        onLoaded: {
            try {
                root.prefs = JSON.parse(text());
            } catch (e) {
                root.prefs = {};
            }
        }
    }

    FileView {
        id: cliFile

        path: root.cliPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.cli = JSON.parse(text());
            } catch (e) {
                root.cli = {};
            }
        }
    }
}
