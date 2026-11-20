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

    property string pendingQuery
    property string query
    // [{ section, label, kind, id, raw, rawList, changed, keys }]
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
                const activeRaw = to === undefined ? bind[1] : to;
                out.push({
                    section,
                    label: cleanLabel(label),
                    kind: raw ? "bind" : "",
                    id: raw,
                    raw: activeRaw,
                    rawList: activeRaw ? [activeRaw] : [],
                    changed: to !== undefined,
                    keys: to === "" ? "" : prettyKeys(to ?? bind[1])
                });
            }
        }
        return out;
    }

    function normKeys(k: string): string {
        if (!k)
            return "";
        const stdMods = ["SUPER", "CTRL", "ALT", "SHIFT"];
        const parts = k.split("+").map(p => p.trim().toUpperCase()).filter(p => p);
        if (parts.length === 0)
            return "";
        const rawKey = parts.pop();
        const key = rawKey.replace(/\s+/g, "_");
        const mods = [];
        for (const p of parts) {
            const m = p === "CONTROL" ? "CTRL" : (p === "WIN" || p === "META" || p === "MOD4" || p === "SUPER_L" || p === "SUPER_R") ? "SUPER" : p === "MOD1" ? "ALT" : p;
            if (!mods.includes(m))
                mods.push(m);
        }
        mods.sort((a, b) => {
            const ia = stdMods.indexOf(a);
            const ib = stdMods.indexOf(b);
            if (ia >= 0 && ib >= 0)
                return ia - ib;
            if (ia >= 0)
                return -1;
            if (ib >= 0)
                return 1;
            return a.localeCompare(b);
        });
        return [...mods, key].join("+");
    }

    function findConflicts(keys: string, exclude: var): var {
        const norm = normKeys(keys);
        if (!norm)
            return [];
        const out = [];
        for (const s of shortcuts) {
            if (exclude && exclude.kind && s.kind === exclude.kind && s.id === exclude.id)
                continue;
            const list = s.rawList ?? [];
            if (list.some(k => normKeys(k) === norm))
                out.push({
                    kind: s.kind,
                    id: s.id,
                    label: s.label,
                    section: s.section
                });
        }
        for (let i = 0; i < customBinds.length; i++) {
            if (exclude && exclude.customIndex === i)
                continue;
            const b = customBinds[i];
            if (normKeys(b.key) === norm)
                out.push({
                    kind: "custom",
                    id: String(i),
                    customIndex: i,
                    label: b.command,
                    section: Tr.tr("Your own shortcuts")
                });
        }
        return out;
    }

    function clearConflicts(conflicts: var): var {
        const removedCustom = [];
        for (const c of conflicts) {
            if (c.kind === "bind")
                HyprSettings.setBindRemap(c.id, "");
            else if (c.kind === "var")
                HyprSettings.setVar(c.id, "");
            else if (c.kind === "custom")
                removedCustom.push(c.customIndex);
        }
        return removedCustom;
    }

    function applySave(item: var, keys: string): void {
        if (item.kind === "var")
            HyprSettings.setVar(item.id, keys);
        else
            HyprSettings.setBindRemap(item.id, keys);
        editing = "";
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
                    rawList: v.filter(x => x && x.trim()),
                    changed: (HyprSettings.saved.vars ?? {})[k] !== undefined,
                    keys: v.map(prettyKeys).join(", ")
                }));
        shortcuts = [...parseBinds(userFile.text(), Tr.tr("Yours")), ...parseBinds(hyprflowFile.text(), Tr.tr("Desktop mode")), ...list];
    }

    // The one being changed (kind/id), and the custom shortcut being added
    property string editing
    readonly property var customBinds: HyprSettings.saved.customBinds ?? []

    function save(item: var, keys: string): void {
        if (keys) {
            const conflicts = findConflicts(keys, {
                kind: item.kind,
                id: item.id
            });
            if (conflicts.length > 0) {
                conflictDialog.pendingAction = {
                    type: "item",
                    item,
                    keys,
                    conflicts
                };
                conflictDialog.open = true;
                return;
            }
        }
        applySave(item, keys);
    }

    function saveCustom(keys: string, command: string): void {
        const cmd = command.trim();
        if (!keys || !cmd)
            return;
        const conflicts = findConflicts(keys, null);
        if (conflicts.length > 0) {
            conflictDialog.pendingAction = {
                type: "custom",
                keys,
                command: cmd,
                conflicts
            };
            conflictDialog.open = true;
            return;
        }
        HyprSettings.setCustomBinds([...root.customBinds, {
                key: keys,
                command: cmd
            }]);
        commandField.text = "";
        addKeys.clear();
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
            label: Tr.tr("Search")
            placeholderText: Tr.tr("A key or an action")
            onValueEdited: v => {
                root.pendingQuery = v;
                queryDelay.restart();
            }
        }

        Timer {
            id: queryDelay

            interval: 200
            onTriggered: root.query = root.pendingQuery
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledTextField {
                        id: commandField

                        Layout.fillWidth: true
                        verticalPadding: Tokens.padding.small
                        floatingPlaceholder: false
                        placeholderText: Tr.tr("Command to run, e.g. firefox --private-window")
                        font: Tokens.font.mono.small
                    }

                    TextButton {
                        text: Tr.tr("Pick app")
                        type: TextButton.Tonal
                        onClicked: appPicker.openPicker({
                            header: Tr.tr("Launch an app"),
                            onPicked: item => {
                                if (item.command)
                                    commandField.text = item.command;
                            }
                        })
                    }
                }

                KeysEditor {
                    id: addKeys

                    Layout.fillWidth: true
                    acceptText: Tr.trCtx("Add", "add a shortcut")
                    acceptEnabled: commandField.text.trim().length > 0
                    conflicts: root.findConflicts(keys, null)
                    onAccepted: keys => root.saveCustom(keys, commandField.text)
                }
            }
        }

        DialogRowButton {
            id: conflictDialog

            property var pendingAction: null

            visible: false
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 360)
            icon: "warning"
            label: ""
            header: Tr.tr("Replace existing shortcut?")
            acceptLabel: Tr.tr("Replace")
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        readonly property string listText: (conflictDialog.pendingAction?.conflicts ?? []).map(c => `${c.label} (${c.section})`).join("\n• ")
                        readonly property bool hasNonEditable: (conflictDialog.pendingAction?.conflicts ?? []).some(c => !c.kind)
                        text: Tr.tr("%1 is already used by:\n• %2\n\nReplacing turns off the previous shortcut.").arg(root.prettyKeys(conflictDialog.pendingAction?.keys ?? "")).arg(listText) + (hasNonEditable ? "\n\n" + Tr.tr("Note: loop shortcuts can't be turned off automatically.") : "")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                const act = pendingAction;
                if (!act)
                    return;
                const removedIdx = root.clearConflicts(act.conflicts);
                const keptCustom = root.customBinds.filter((_, idx) => !removedIdx.includes(idx));
                if (act.type === "custom") {
                    HyprSettings.setCustomBinds([...keptCustom, {
                            key: act.keys,
                            command: act.command
                        }]);
                    commandField.text = "";
                    addKeys.clear();
                } else {
                    if (removedIdx.length > 0)
                        HyprSettings.setCustomBinds(keptCustom);
                    root.applySave(act.item, act.keys);
                }
                pendingAction = null;
            }
        }

        AppPickerDialog {
            id: appPicker

            hostFlickable: root.flickable
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        // The four files load one after another: build the list once, after them
        Timer {
            id: rebuildTimer

            interval: 30
            onTriggered: root.rebuild()
        }

        Connections {
            function onSavedChanged(): void {
                rebuildTimer.restart();
            }

            target: HyprSettings
        }

        FileView {
            id: defaultsFile

            path: `${root.hyprDir}/variables.lua`
            printErrors: false
            onLoaded: rebuildTimer.restart()
        }

        FileView {
            id: overridesFile

            path: `${root.caelestiaDir}/hypr-vars.lua`
            printErrors: false
            onLoaded: rebuildTimer.restart()
        }

        FileView {
            id: userFile

            path: `${root.caelestiaDir}/hypr-user.lua`
            printErrors: false
            onLoaded: rebuildTimer.restart()
        }

        FileView {
            id: hyprflowFile

            path: `${root.caelestiaDir}/hyprflow.lua`
            printErrors: false
            onLoaded: rebuildTimer.restart()
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
        property var conflicts: []
        readonly property list<string> mods: ["SUPER", "CTRL", "ALT", "SHIFT"]
        property var held: ({})
        property bool recording: false
        property var liveMods: ({})
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

        function qtKeyToHypr(key: int): string {
            const modKeys = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Meta, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R];
            if (modKeys.includes(key))
                return "";
            if (key >= Qt.Key_A && key <= Qt.Key_Z)
                return String.fromCharCode(key);
            if (key >= Qt.Key_0 && key <= Qt.Key_9)
                return String.fromCharCode(key);
            if (key >= Qt.Key_F1 && key <= Qt.Key_F24)
                return `F${key - Qt.Key_F1 + 1}`;
            const map = {
                [Qt.Key_Return]: "RETURN",
                [Qt.Key_Enter]: "RETURN",
                [Qt.Key_Space]: "SPACE",
                [Qt.Key_Tab]: "TAB",
                [Qt.Key_Backtab]: "TAB",
                [Qt.Key_Backspace]: "BACKSPACE",
                [Qt.Key_Delete]: "DELETE",
                [Qt.Key_Insert]: "INSERT",
                [Qt.Key_Home]: "HOME",
                [Qt.Key_End]: "END",
                [Qt.Key_PageUp]: "PRIOR",
                [Qt.Key_PageDown]: "NEXT",
                [Qt.Key_Left]: "LEFT",
                [Qt.Key_Right]: "RIGHT",
                [Qt.Key_Up]: "UP",
                [Qt.Key_Down]: "DOWN",
                [Qt.Key_Print]: "PRINT",
                [Qt.Key_Pause]: "PAUSE",
                [Qt.Key_CapsLock]: "CAPS_LOCK",
                [Qt.Key_Minus]: "MINUS",
                [Qt.Key_Equal]: "EQUAL",
                [Qt.Key_Plus]: "EQUAL",
                [Qt.Key_BracketLeft]: "BRACKETLEFT",
                [Qt.Key_BracketRight]: "BRACKETRIGHT",
                [Qt.Key_Semicolon]: "SEMICOLON",
                [Qt.Key_Apostrophe]: "APOSTROPHE",
                [Qt.Key_Comma]: "COMMA",
                [Qt.Key_Period]: "PERIOD",
                [Qt.Key_Slash]: "SLASH",
                [Qt.Key_Backslash]: "BACKSLASH",
                [Qt.Key_QuoteLeft]: "GRAVE",
                [Qt.Key_VolumeUp]: "XF86AUDIORAISEVOLUME",
                [Qt.Key_VolumeDown]: "XF86AUDIOLOWERVOLUME",
                [Qt.Key_VolumeMute]: "XF86AUDIOMUTE",
                [Qt.Key_MicMute]: "XF86AUDIOMICMUTE",
                [Qt.Key_MediaPlay]: "XF86AUDIOPLAY",
                [Qt.Key_MediaTogglePlayPause]: "XF86AUDIOPLAY",
                [Qt.Key_MediaNext]: "XF86AUDIONEXT",
                [Qt.Key_MediaPrevious]: "XF86AUDIOPREV",
                [Qt.Key_MediaStop]: "XF86AUDIOSTOP",
                [Qt.Key_MonBrightnessUp]: "XF86MONBRIGHTNESSUP",
                [Qt.Key_MonBrightnessDown]: "XF86MONBRIGHTNESSDOWN"
            };
            return map[key] ?? "";
        }

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
            recording = false;
            liveMods = {};
        }

        onVisibleChanged: {
            if (visible && initial)
                load(initial);
            if (!visible) {
                recording = false;
                liveMods = {};
            }
        }
        Component.onCompleted: {
            if (initial)
                load(initial);
        }

        spacing: Tokens.spacing.small

        Item {
            id: recorder

            width: 0
            height: 0
            focus: editor.recording
            onActiveFocusChanged: if (!activeFocus && editor.recording) {
                editor.recording = false;
                editor.liveMods = {};
            }
            Keys.onPressed: event => {
                if (!editor.recording)
                    return;
                event.accepted = true;
                if (event.key === Qt.Key_Escape) {
                    editor.recording = false;
                    editor.liveMods = {};
                    return;
                }
                const m = {
                    SUPER: !!(event.modifiers & Qt.MetaModifier) || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta,
                    CTRL: !!(event.modifiers & Qt.ControlModifier) || event.key === Qt.Key_Control,
                    ALT: !!(event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt,
                    SHIFT: !!(event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Shift
                };
                const k = editor.qtKeyToHypr(event.key);
                if (!k) {
                    editor.liveMods = m;
                    return;
                }
                editor.held = {
                    SUPER: !!(event.modifiers & Qt.MetaModifier),
                    CTRL: !!(event.modifiers & Qt.ControlModifier),
                    ALT: !!(event.modifiers & Qt.AltModifier),
                    SHIFT: !!(event.modifiers & Qt.ShiftModifier)
                };
                keyField.text = k;
                editor.liveMods = {};
                editor.recording = false;
            }
            Keys.onReleased: event => {
                if (!editor.recording)
                    return;
                event.accepted = true;
                editor.liveMods = {
                    SUPER: !!(event.modifiers & Qt.MetaModifier),
                    CTRL: !!(event.modifiers & Qt.ControlModifier),
                    ALT: !!(event.modifiers & Qt.AltModifier),
                    SHIFT: !!(event.modifiers & Qt.ShiftModifier)
                };
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            TextButton {
                text: editor.recording ? Tr.tr("Press keys… (Esc to cancel)") : Tr.tr("Record keys")
                type: editor.recording ? TextButton.Filled : TextButton.Tonal
                onClicked: {
                    editor.recording = !editor.recording;
                    editor.liveMods = {};
                    if (editor.recording)
                        Qt.callLater(() => {
                            if (editor.recording)
                                recorder.forceActiveFocus();
                        });
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (!editor.recording)
                        return Tr.tr("Or adjust modifiers and key below:");
                    const active = editor.mods.filter(m => editor.liveMods[m]);
                    return active.length > 0 ? [...active, "…"].join(" + ") : Tr.tr("Press your shortcut now");
                }
                color: editor.recording ? Colours.palette.m3primary : Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: editor.mods

                TextButton {
                    required property string modelData

                    text: modelData.charAt(0) + modelData.slice(1).toLowerCase()
                    isToggle: true
                    followChecked: true
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
                verticalPadding: Tokens.padding.small
                floatingPlaceholder: false
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
            visible: editor.conflicts.length > 0
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "warning"
                color: Colours.palette.m3error
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Already used by %1").arg(editor.conflicts.map(c => c.label).join(", "))
                color: Colours.palette.m3error
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
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

            // Made only for the row being changed: one per row (150 of them)
            // made the page slow to open
            Loader {
                Layout.fillWidth: true
                active: srow.open
                visible: active

                sourceComponent: KeysEditor {
                    initial: srow.item.raw
                    acceptText: Tr.trCtx("Save", "button")
                    cancellable: true
                    canTurnOff: srow.item.kind === "bind"
                    canReset: srow.item.changed
                    conflicts: root.findConflicts(keys, {
                        kind: srow.item.kind,
                        id: srow.item.id
                    })
                    onAccepted: keys => root.save(srow.item, keys)
                    onCancelled: root.editing = ""
                    onTurnedOff: root.save(srow.item, "")
                    onResetClicked: root.reset(srow.item)
                }
            }
        }
    }
}
