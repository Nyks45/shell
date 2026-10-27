pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.utils
import qs.modules.nexus.common

// The keyboard shortcuts, read from the config: Caelestia's named ones
// (variables.lua, with hypr-vars.lua's overrides) and the commented hl.bind
// lines in the user's own files. (Hyprland itself only knows them as Lua
// functions, without names.)
PageBase {
    id: root

    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/hypr`
    readonly property string caelestiaDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/caelestia`

    property string query
    // [{ section, label, keys }]
    property var shortcuts: []
    readonly property var shown: shortcuts.filter(s => !query || `${s.label} ${s.keys}`.toLowerCase().includes(query.toLowerCase()))
    readonly property list<string> sections: [...new Set(shown.map(s => s.section))]

    // Better names for some of Caelestia's
    readonly property var names: ({
            kbGoToWs: Tr.tr("Go to workspace 1-10 (with 1-0)"),
            kbGoToWsGroup: Tr.tr("Go to workspace group (with 1-0)"),
            kbMoveWinToWs: Tr.tr("Move the window to workspace 1-10 (with 1-0)"),
            kbMoveWinToWsGroup: Tr.tr("Move the window to workspace group (with 1-0)"),
            kbWindowPip: Tr.tr("Picture in picture"),
            kbSpecialWs: Tr.tr("Scratchpad workspace")
        })

    function prettyKeys(k: string): string {
        return k.split("+").map(p => {
            const s = p.trim();
            return s.length > 1 ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase().replace(/_(.)/g, (m, c) => ` ${c}`) : s;
        }).join(" + ").replace("Mouse down", "Wheel down").replace("Mouse up", "Wheel up");
    }

    // kbCloseWindow -> "Close window"
    function labelFor(name: string): string {
        if (names[name])
            return names[name];
        const words = name.replace(/^kb/, "").replace(/([A-Z])/g, " $1").trim().toLowerCase().replace(/\bws\b/g, "workspace").replace(/\bwin\b/g, "window");
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    // kbX = "A + B" | { "A", "B" } from a Lua file
    function parseVars(text: string): var {
        const out = {};
        for (const m of Strings.allMatches(text, /^\s*(kb\w+)\s*=\s*(\{[^}]*\}|"[^"]*")/gm))
            out[m[1]] = Strings.allMatches(m[2], /"([^"]*)"/g).map(x => x[1]);
        return out;
    }

    // hl.bind("KEYS", ...) with a trailing comment, or the comment above it
    // "Alt+Tab: the overview as a window switcher (...); ..." -> "The overview as a window switcher"
    function cleanLabel(text: string): string {
        let s = text.trim();
        const keyed = s.match(/^[^:]{1,30}:\s+(.+)$/);
        if (keyed)
            s = keyed[1];
        s = s.split(/;|\. | \(/)[0].replace(/[.,]$/, "").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // hl.bind("KEYS", ...): named by its trailing comment, else by the comment
    // block above it (which covers the binds up to the next blank line)
    function parseBinds(text: string, section: string): var {
        const out = [];
        let block = "", inBlock = false;
        for (const line of text.split("\n")) {
            const comment = line.match(/^\s*--\s*(.+)$/);
            if (comment) {
                if (!inBlock)
                    block = comment[1];
                inBlock = true;
                continue;
            }
            inBlock = false;
            if (!line.trim()) {
                block = "";
                continue;
            }
            // "SUPER + " .. d[1] in a loop over the arrow keys: "Super + Arrows"
            const bind = line.match(/hl\.bind\("([^"]+)"(\s*\.\.)?/);
            if (bind && bind[2])
                bind[1] = `${bind[1].trim().replace(/\+$/, "").trim()} + ARROWS`;
            const label = bind ? (line.match(/\)\s*--\s*(.+)$/)?.[1] || block) : "";
            if (label)
                out.push({
                    section,
                    label: cleanLabel(label),
                    keys: prettyKeys(bind[1])
                });
        }
        return out;
    }

    function rebuild(): void {
        const vars = parseVars(defaultsFile.text());
        Object.assign(vars, parseVars(overridesFile.text()));
        for (const [k, v] of Object.entries(HyprSettings.saved.vars ?? {}))
            if (k.startsWith("kb"))
                vars[k] = Array.isArray(v) ? v : [v];

        const list = Object.entries(vars).filter(([k, v]) => v.length > 0).map(([k, v]) => ({
                    section: Tr.tr("Caelestia"),
                    label: labelFor(k),
                    keys: v.map(prettyKeys).join(", ")
                }));
        shortcuts = [...parseBinds(userFile.text(), Tr.tr("Yours")), ...parseBinds(hyprflowFile.text(), Tr.tr("Desktop mode")), ...list];
    }

    title: Tr.tr("Keyboard shortcuts")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        TextFieldRow {
            first: true
            last: true
            label: Tr.tr("Search")
            placeholderText: Tr.tr("A key or an action")
            onValueEdited: v => root.query = v
        }

        Repeater {
            model: root.sections

            ColumnLayout {
                id: section

                required property string modelData
                readonly property var items: root.shown.filter(s => s.section === modelData)

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: section.modelData
                }

                Repeater {
                    model: section.items

                    InfoRow {
                        required property var modelData
                        required property int index

                        first: index === 0
                        last: index === section.items.length - 1
                        label: modelData.label
                        value: modelData.keys
                    }
                }
            }
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        FileView {
            id: defaultsFile

            path: `${root.hyprDir}/variables.lua`
            printErrors: false
            onLoaded: root.rebuild()
        }

        FileView {
            id: overridesFile

            path: `${root.caelestiaDir}/hypr-vars.lua`
            printErrors: false
            onLoaded: root.rebuild()
        }

        FileView {
            id: userFile

            path: `${root.caelestiaDir}/hypr-user.lua`
            printErrors: false
            onLoaded: root.rebuild()
        }

        FileView {
            id: hyprflowFile

            path: `${root.caelestiaDir}/hyprflow.lua`
            printErrors: false
            onLoaded: root.rebuild()
        }
    }
}
