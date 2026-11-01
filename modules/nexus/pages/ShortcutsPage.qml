pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
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
            if (label) {
                // Loop binds ("+ ARROWS") can't be moved one by one
                const raw = bind[2] ? "" : bind[1];
                const to = raw ? HyprSettings.saved.remap?.[raw] : undefined;
                out.push({
                    section,
                    label: cleanLabel(label),
                    kind: raw ? "bind" : "",
                    id: raw,
                    raw: to === undefined ? bind[1] : to,
                    changed: to !== undefined,
                    keys: to === "" ? "" : prettyKeys(to ?? bind[1])
                });
            }
        }
        return out;
    }

    function rebuild(): void {
        const vars = parseVars(defaultsFile.text());
        Object.assign(vars, parseVars(overridesFile.text()));
        const fromFiles = Object.assign({}, vars);
        for (const [k, v] of Object.entries(HyprSettings.saved.vars ?? {}))
            if (k.startsWith("kb"))
                vars[k] = Array.isArray(v) ? v : [v];

        const list = Object.entries(vars).filter(([k, v]) => v.length > 0 || fromFiles[k]?.length > 0).map(([k, v]) => ({
                    section: Tr.tr("Caelestia"),
                    label: labelFor(k),
                    // One full combination (not a modifier for 1-0, not a list) can be changed here
                    kind: v.length <= 1 && (v[0] ?? fromFiles[k]?.[0] ?? "").includes("+") || v.length === 0 ? "var" : "",
                    id: k,
                    raw: v[0] ?? "",
                    changed: (HyprSettings.saved.vars ?? {})[k] !== undefined,
                    keys: v.map(prettyKeys).join(", ")
                }));
        shortcuts = [...parseBinds(userFile.text(), Tr.tr("Yours")), ...parseBinds(hyprflowFile.text(), Tr.tr("Desktop mode")), ...list];
    }

    // The one being changed (kind/id), and the custom shortcut being added
    property string editing
    readonly property var customBinds: HyprSettings.saved.customBinds ?? []

    function save(item: var, keys: string): void {
        if (item.kind === "var")
            HyprSettings.setVar(item.id, keys);
        else
            HyprSettings.setBindRemap(item.id, keys);
        editing = "";
    }

    function reset(item: var): void {
        if (item.kind === "var")
            HyprSettings.unsetVar(item.id);
        else
            HyprSettings.setBindRemap(item.id, null);
        editing = "";
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

                    ShortcutRow {
                        required property var modelData
                        required property int index

                        first: index === 0
                        last: index === section.items.length - 1
                        item: modelData
                    }
                }
            }
        }

        // The user's own: a key that runs a command
        SectionHeader {
            visible: !root.query
            text: Tr.tr("Your own shortcuts")
        }

        Repeater {
            model: root.query ? [] : root.customBinds

            ConnectedRect {
                id: custom

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                implicitHeight: customRow.implicitHeight + Tokens.padding.small * 2

                RowLayout {
                    id: customRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: custom.modelData.command
                        font: Tokens.font.mono.small
                        elide: Text.ElideRight
                    }

                    KeysChip {
                        text: root.prettyKeys(custom.modelData.key)
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        onClicked: {
                            const next = [...root.customBinds];
                            next.splice(custom.index, 1);
                            HyprSettings.setCustomBinds(next);
                        }
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: !root.query
            first: root.customBinds.length === 0
            last: true
            implicitHeight: addLayout.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: addLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    text: Tr.tr("Add a shortcut")
                    font: Tokens.font.body.small
                }

                StyledTextField {
                    id: commandField

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Command to run, e.g. firefox --private-window")
                    font: Tokens.font.mono.small
                }

                KeysEditor {
                    id: addKeys

                    Layout.fillWidth: true
                    acceptText: Tr.trCtx("Add", "add a shortcut")
                    acceptEnabled: commandField.text.trim().length > 0
                    onAccepted: keys => {
                        HyprSettings.setCustomBinds([...root.customBinds, {
                                key: keys,
                                command: commandField.text.trim()
                            }]);
                        commandField.text = "";
                        addKeys.clear();
                    }
                }
            }
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Connections {
            function onSavedChanged(): void {
                root.rebuild();
            }

            target: HyprSettings
        }

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

    component KeysChip: StyledRect {
        property alias text: chipText.text

        // Several key combinations: at most half the row, the rest elided
        Layout.maximumWidth: root.cappedWidth * 0.5
        implicitWidth: chipText.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: chipText.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.small
        color: Colours.tPalette.m3surfaceContainerHighest

        StyledText {
            id: chipText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font: Tokens.font.label.medium
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // Modifiers as toggles and the key as text: "SUPER + SHIFT + D"
    component KeysEditor: ColumnLayout {
        id: editor

        property string initial
        property string acceptText
        property bool acceptEnabled: true
        property bool cancellable
        property bool canTurnOff
        property bool canReset
        readonly property list<string> mods: ["SUPER", "CTRL", "ALT", "SHIFT"]
        property var held: ({})
        readonly property string keys: {
            const k = keyField.text.trim().toUpperCase().replace(/\s+/g, "_");
            if (!k)
                return "";
            return [...mods.filter(m => held[m]), k].join(" + ");
        }

        signal accepted(keys: string)
        signal cancelled
        signal turnedOff
        signal resetClicked

        function load(text: string): void {
            const parts = text.split("+").map(p => p.trim().toUpperCase()).filter(p => p);
            const next = {};
            let key = "";
            for (const p of parts) {
                const m = p === "CONTROL" ? "CTRL" : p === "WIN" || p === "META" || p === "MOD4" ? "SUPER" : p;
                if (mods.includes(m))
                    next[m] = true;
                else
                    key = p;
            }
            held = next;
            keyField.text = key;
        }

        function clear(): void {
            held = {};
            keyField.text = "";
        }

        onVisibleChanged: {
            if (visible && initial)
                load(initial);
        }
        Component.onCompleted: {
            if (initial)
                load(initial);
        }

        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: editor.mods

                TextButton {
                    required property string modelData

                    text: modelData.charAt(0) + modelData.slice(1).toLowerCase()
                    isToggle: true
                    checked: !!editor.held[modelData]
                    type: TextButton.Tonal
                    onClicked: {
                        const next = Object.assign({}, editor.held);
                        next[modelData] = !next[modelData];
                        editor.held = next;
                    }
                }
            }

            StyledText {
                text: "+"
                color: Colours.palette.m3outline
            }

            StyledTextField {
                id: keyField

                Layout.fillWidth: true
                placeholderText: Tr.tr("Key, e.g. D, F5, Return, Print")
                font: Tokens.font.mono.small
                onAccepted: {
                    if (editor.keys && editor.acceptEnabled)
                        editor.accepted(editor.keys);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: editor.keys ? root.prettyKeys(editor.keys) : ""
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            TextButton {
                visible: editor.canTurnOff
                text: Tr.tr("Turn off")
                type: TextButton.Text
                onClicked: editor.turnedOff()
            }

            TextButton {
                visible: editor.canReset
                text: Tr.tr("Reset")
                type: TextButton.Text
                onClicked: editor.resetClicked()
            }

            TextButton {
                visible: editor.cancellable
                text: Tr.trCtx("Cancel", "button")
                type: TextButton.Text
                onClicked: editor.cancelled()
            }

            TextButton {
                text: editor.acceptText
                type: TextButton.Filled
                disabled: !editor.keys || !editor.acceptEnabled
                onClicked: editor.accepted(editor.keys)
            }
        }
    }

    // A shortcut: its keys; clicking one that can be changed opens its editor
    component ShortcutRow: ConnectedRect {
        id: srow

        property var item
        readonly property bool editable: !!item.kind
        readonly property bool open: root.editing === `${item.kind}/${item.id}` && editable

        Layout.fillWidth: true
        implicitHeight: srowLayout.implicitHeight + Tokens.padding.medium * 2
        clip: true

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        StateLayer {
            anchors.fill: parent
            radius: srow.topLeftRadius
            disabled: !srow.editable || srow.open
            showHoverBackground: srow.editable
            onClicked: root.editing = `${srow.item.kind}/${srow.item.id}`
        }

        ColumnLayout {
            id: srowLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: srow.item.label
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: srow.item.changed
                        text: srow.item.keys ? Tr.tr("Changed") : Tr.tr("Turned off")
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.small
                    }
                }

                KeysChip {
                    visible: !!srow.item.keys
                    text: srow.item.keys
                }

                MaterialIcon {
                    visible: srow.editable && !srow.open
                    text: "edit"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.small
                }
            }

            KeysEditor {
                Layout.fillWidth: true
                visible: srow.open
                initial: srow.item.raw
                acceptText: Tr.trCtx("Save", "button")
                cancellable: true
                canTurnOff: srow.item.kind === "bind"
                canReset: srow.item.changed
                onAccepted: keys => root.save(srow.item, keys)
                onCancelled: root.editing = ""
                onTurnedOff: root.save(srow.item, "")
                onResetClicked: root.reset(srow.item)
            }
        }
    }
}
