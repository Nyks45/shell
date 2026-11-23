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
    property bool changedOnly: false
    // [{ section, label, kind, id, raw, rawList, changed, keys, reason }]
    property var shortcuts: []
    readonly property int changedCount: shortcuts.filter(s => s.changed).length
    readonly property var shown: shortcuts.filter(s => (!changedOnly || s.changed) && (!query || `${s.label} ${s.keys} ${s.raw ?? ""}`.toLowerCase().includes(query.toLowerCase())))
    readonly property list<string> categoryOrder: [Tr.tr("Windows"), Tr.tr("Workspaces"), Tr.tr("Apps"), Tr.tr("Screenshots & media"), Tr.tr("Desktop & shell"), Tr.tr("Other")]
    readonly property list<string> sections: categoryOrder.filter(c => shown.some(s => s.section === c))

    // Friendly action names for Caelestia's variable-backed shortcuts
    readonly property var names: ({
            kbGoToWs: Tr.tr("Go to workspace 1–10 (hold modifier + 1–0)"),
            kbGoToWsGroup: Tr.tr("Go to workspace group (hold modifier + 1–0)"),
            kbMoveWinToWs: Tr.tr("Move window to workspace 1–10 (hold modifier + 1–0)"),
            kbMoveWinToWsGroup: Tr.tr("Move window to workspace group (hold modifier + 1–0)"),
            kbMoveWinToWsSpecial: Tr.tr("Move window to scratchpad"),
            kbMoveWinFromWsSpecial: Tr.tr("Move window out of scratchpad"),
            kbWindowPip: Tr.tr("Picture in picture"),
            kbWindowBorderedFullscreen: Tr.tr("Maximize window (keep bar)"),
            kbGroupLockActive: Tr.tr("Lock window group"),
            kbSpecialWs: Tr.tr("Scratchpad workspace"),
            kbSystemMonitorWs: Tr.tr("System monitor workspace"),
            kbMusicWs: Tr.tr("Music workspace"),
            kbCommunicationWs: Tr.tr("Communication workspace"),
            kbTodoWs: Tr.tr("To-do workspace"),
            kbRestoreLock: Tr.tr("Restore lock screen"),
            kbShowPanels: Tr.tr("Show all shell panels"),
            kbClearNotifs: Tr.tr("Clear notifications"),
            kbClipboardDel: Tr.tr("Delete from clipboard history"),
            kbClipboardPasteLatest: Tr.tr("Paste latest clipboard item"),
            kbScreenshotFreeze: Tr.tr("Screenshot (freeze screen)"),
            kbScreenshotRegion: Tr.tr("Screenshot region"),
            kbRecordSound: Tr.tr("Record screen with audio"),
            kbRecordRegion: Tr.tr("Record region")
        })

    function categoryFor(id: string, label: string): string {
        const key = id.toLowerCase();
        const text = label.toLowerCase();
        if (key.startsWith("kb")) {
            if (/ws|workspace|scratchpad/.test(key))
                return Tr.tr("Workspaces");
            if (/^(kbwindow|kbcenter|kbnormalize|kbpin|kbclose|kbungroup|kbtogglegroup|kbgrouplock|kbmovewindow|kbresizewindow)/.test(key))
                return Tr.tr("Windows");
            if (/^(kbterminal|kbbrowser|kbeditor|kbfileexplorer|kbaudiodetect|kbaudiosettings)/.test(key))
                return Tr.tr("Apps");
            if (/^(kbscreenshot|kbrecord|kbcolorpicker|kbmedia|kbvolume)/.test(key))
                return Tr.tr("Screenshots & media");
            return Tr.tr("Desktop & shell");
        }
        if (/xf86(monbrightness|audio)/.test(key) || /brightness|volume|media|microphone|screenshot|record/.test(text))
            return Tr.tr("Screenshots & media");
        if (/workspace|scratchpad|column|window|focus|move|arrange|center window|fill|switcher|overview as a window|fit|zen|promote|placement/.test(text))
            return Tr.tr("Windows");
        if (/terminal|browser|editor|files|audio settings|wallpaper settings|task manager|widget|desktop mode|shell|session|sidebar|lock|sleep|clipboard|emoji/.test(text))
            return Tr.tr("Desktop & shell");
        return Tr.tr("Other");
    }

    function prettyKeys(k: string): string {
        const tokenNames = {
            "mouse:272": Tr.tr("Left click"),
            "mouse_left": Tr.tr("Left click"),
            "mouse:273": Tr.tr("Right click"),
            "mouse_right": Tr.tr("Right click"),
            "mouse:274": Tr.tr("Middle click"),
            "mouse_middle": Tr.tr("Middle click"),
            "mouse_down": Tr.tr("Wheel down"),
            "mouse_up": Tr.tr("Wheel up"),
            "super_l": "Super",
            "super_r": "Super",
            "arrows": Tr.tr("Arrow keys"),
            "xf86monbrightnessup": Tr.tr("Brightness Up"),
            "xf86monbrightnessdown": Tr.tr("Brightness Down"),
            "xf86audioraisevolume": Tr.tr("Volume Up"),
            "xf86audiolowervolume": Tr.tr("Volume Down"),
            "xf86audiomute": Tr.tr("Mute Audio"),
            "xf86audiomicmute": Tr.tr("Mute Mic"),
            "xf86audioplay": Tr.tr("Media Play"),
            "xf86audiopause": Tr.tr("Media Pause"),
            "xf86audionext": Tr.tr("Media Next"),
            "xf86audioprev": Tr.tr("Media Previous"),
            "xf86audiostop": Tr.tr("Media Stop"),
            "page_up": "Page Up",
            "page_down": "Page Down",
            "prior": "Page Up",
            "next": "Page Down",
            "backslash": "\\",
            "minus": "-",
            "equal": "=",
            "comma": ",",
            "period": ".",
            "kp_add": "Numpad +",
            "kp_subtract": "Numpad -",
            "escape": "Esc"
        };
        return k.split("+").map(p => {
            const s = p.trim();
            const mapped = tokenNames[s.toLowerCase()];
            if (mapped)
                return mapped;
            return s.length > 1 ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase().replace(/_(.)/g, (m, c) => ` ${c}`) : s;
        }).join(" + ");
    }

    // kbCloseWindow -> "Close window"
    function labelFor(name: string): string {
        if (names[name])
            return names[name];
        const words = name.replace(/^kb/, "").replace(/([A-Z])/g, " $1").trim().toLowerCase().replace(/\bws\b/g, "workspace").replace(/\bwin\b/g, "window").replace(/\bnotifs\b/g, "notifications").replace(/\bdel\b/g, "delete");
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

    // hl.bind("KEYS", ...): named by its trailing comment or description, else by
    // the comment block above it (which covers the binds up to the next blank line)
    function parseBinds(text: string): var {
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
            const label = bind ? (line.match(/\)\s*--\s*(.+)$/)?.[1] || line.match(/description\s*=\s*"([^"]+)"/)?.[1] || block) : "";
            if (label) {
                // Loop binds ("+ ARROWS") can't be moved one by one
                const clean = cleanLabel(label);
                const raw = bind[2] ? "" : bind[1];
                const to = raw ? HyprSettings.saved.remap?.[raw] : undefined;
                const activeRaw = to === undefined ? bind[1] : to;
                out.push({
                    section: categoryFor(raw || bind[1], clean),
                    label: clean,
                    kind: raw ? "bind" : "",
                    id: raw,
                    raw: activeRaw,
                    rawList: activeRaw ? [activeRaw] : [],
                    changed: to !== undefined,
                    keys: to === "" ? "" : prettyKeys(to ?? bind[1]),
                    reason: bind[2] ? Tr.tr("Direction group — applies to all four arrow keys") : ""
                });
            }
        }
        return out;
    }

    function builtInBinds(kbText: string): var {
        if (!kbText)
            return [];
        const defs = [
            { raw: "CTRL + SUPER + SHIFT + R", check: "CTRL + SUPER + SHIFT + R", label: Tr.tr("Stop shell") },
            { raw: "CTRL + SUPER + ALT + R", check: "CTRL + SUPER + ALT + R", label: Tr.tr("Restart shell") },
            { raw: "SUPER + ARROWS", check: '"SUPER + " .. dir', label: Tr.tr("Focus window by direction"), loop: true },
            { raw: "SUPER + SHIFT + ARROWS", check: '"SUPER + SHIFT + " .. dir', label: Tr.tr("Move window by direction"), loop: true },
            { raw: "XF86MonBrightnessUp", check: "XF86MonBrightnessUp", label: Tr.tr("Increase brightness") },
            { raw: "XF86MonBrightnessDown", check: "XF86MonBrightnessDown", label: Tr.tr("Decrease brightness") },
            { raw: "XF86AudioRaiseVolume", check: "XF86AudioRaiseVolume", label: Tr.tr("Increase volume") },
            { raw: "XF86AudioLowerVolume", check: "XF86AudioLowerVolume", label: Tr.tr("Decrease volume") },
            { raw: "XF86AudioMute", check: "XF86AudioMute", label: Tr.tr("Mute audio (media key)") },
            { raw: "XF86AudioMicMute", check: "XF86AudioMicMute", label: Tr.tr("Mute microphone") },
            { raw: "XF86AudioPlay", check: "XF86AudioPlay", label: Tr.tr("Play media") },
            { raw: "XF86AudioPause", check: "XF86AudioPause", label: Tr.tr("Pause media") },
            { raw: "XF86AudioNext", check: "XF86AudioNext", label: Tr.tr("Next track (media key)") },
            { raw: "XF86AudioPrev", check: "XF86AudioPrev", label: Tr.tr("Previous track (media key)") },
            { raw: "XF86AudioStop", check: "XF86AudioStop", label: Tr.tr("Stop media (media key)") }
        ];
        const out = [];
        for (const d of defs) {
            if (!kbText.includes(d.check))
                continue;
            const id = d.loop ? "" : d.raw;
            const to = id ? HyprSettings.saved.remap?.[id] : undefined;
            const activeRaw = to === undefined ? d.raw : to;
            out.push({
                section: categoryFor(d.raw, d.label),
                label: d.label,
                kind: id ? "bind" : "",
                id,
                raw: activeRaw,
                rawList: activeRaw ? [activeRaw] : [],
                changed: to !== undefined,
                keys: to === "" ? "" : prettyKeys(to ?? d.raw),
                reason: d.loop ? Tr.tr("Direction group — applies to all four arrow keys") : ""
            });
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
                    section: s.section,
                    reason: s.reason ?? ""
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

        const list = Object.entries(vars).filter(([k, v]) => v.length > 0 || fromFiles[k]?.length > 0).map(([k, v]) => {
            const label = labelFor(k);
            const rawList = v.filter(x => x && x.trim());
            // Turned off ("", from Replace) is judged by its default; editable =
            // one combination that isn't just modifiers (those prefix 1-0)
            const base = rawList[0] ?? fromFiles[k]?.[0] ?? "";
            const modsOnly = base.split(/[+\s]+/).filter(x => x).every(x => /^(super|alt|ctrl|control|shift|mod\d?|super_[lr]|alt_[lr]|ctrl_[lr]|shift_[lr])$/i.test(x));
            const editable = rawList.length <= 1 && (fromFiles[k]?.length ?? 0) <= 1 && !!base && !modsOnly;
            let reason = "";
            if (!editable) {
                if (!modsOnly)
                    reason = Tr.tr("Multiple key combinations — edit in hypr-vars.lua");
                else
                    reason = Tr.tr("Modifier prefix — hold together with number keys 1–0");
            }
            return {
                section: categoryFor(k, label),
                label,
                // One full combination (not a modifier for 1-0, not a list) can be changed here
                kind: editable ? "var" : "",
                id: k,
                raw: v[0] ?? "",
                rawList,
                changed: (HyprSettings.saved.vars ?? {})[k] !== undefined,
                keys: v.map(prettyKeys).join(", "),
                reason
            };
        });
        const extra = [];
        if (HyprSettings.saved.magnifierShortcuts !== false) {
            const magReason = Tr.tr("Managed in Accessibility › Magnifier keyboard shortcuts");
            extra.push({
                section: Tr.tr("Desktop & shell"),
                label: Tr.tr("Magnifier zoom in"),
                kind: "",
                id: "",
                raw: "SUPER + ALT + Equal",
                rawList: ["SUPER + ALT + Equal", "SUPER + KP_Add"],
                changed: false,
                keys: `${prettyKeys("SUPER + ALT + Equal")}, ${prettyKeys("SUPER + KP_Add")}`,
                reason: magReason
            }, {
                section: Tr.tr("Desktop & shell"),
                label: Tr.tr("Magnifier zoom out"),
                kind: "",
                id: "",
                raw: "SUPER + ALT + Minus",
                rawList: ["SUPER + ALT + Minus", "SUPER + KP_Subtract"],
                changed: false,
                keys: `${prettyKeys("SUPER + ALT + Minus")}, ${prettyKeys("SUPER + KP_Subtract")}`,
                reason: magReason
            }, {
                section: Tr.tr("Desktop & shell"),
                label: Tr.tr("Reset magnifier zoom"),
                kind: "",
                id: "",
                raw: "SUPER + Escape",
                rawList: ["SUPER + Escape"],
                changed: false,
                keys: prettyKeys("SUPER + Escape"),
                reason: magReason
            });
        }
        shortcuts = [...parseBinds(userFile.text()), ...parseBinds(hyprflowFile.text()), ...builtInBinds(keybindsFile.text()), ...list, ...extra];
    }

    // The one being changed (kind/id), and the custom shortcut index being edited (-1 = none)
    property string editing
    property int editingCustomIndex: -1
    readonly property var customBinds: HyprSettings.saved.customBinds ?? []

    function resetAllChanges(): void {
        const vars = Object.assign({}, HyprSettings.saved.vars ?? {});
        for (const k of Object.keys(vars)) {
            if (k.startsWith("kb"))
                delete vars[k];
        }
        HyprSettings.update({
            vars,
            remap: {}
        });
        editing = "";
        changedOnly = false;
    }

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

    function saveCustom(keys: string, command: string, editIndex: int): void {
        const cmd = command.trim();
        if (!keys || !cmd)
            return;
        const exclude = editIndex >= 0 ? {
            kind: "custom",
            customIndex: editIndex
        } : null;
        const conflicts = findConflicts(keys, exclude);
        if (conflicts.length > 0) {
            conflictDialog.pendingAction = {
                type: "custom",
                editIndex,
                keys,
                command: cmd,
                conflicts
            };
            conflictDialog.open = true;
            return;
        }
        if (editIndex >= 0 && editIndex < root.customBinds.length) {
            const next = [...root.customBinds];
            next[editIndex] = {
                key: keys,
                command: cmd
            };
            HyprSettings.setCustomBinds(next);
            root.editingCustomIndex = -1;
        } else {
            HyprSettings.setCustomBinds([...root.customBinds, {
                    key: keys,
                    command: cmd
                }]);
            commandField.text = "";
            addKeys.clear();
        }
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            TextButton {
                text: root.changedCount > 0 ? Tr.tr("Changed only (%1)").arg(root.changedCount) : Tr.tr("Changed only")
                isToggle: true
                followChecked: true
                checked: root.changedOnly
                type: TextButton.Tonal
                onClicked: root.changedOnly = !root.changedOnly
            }

            Item {
                Layout.fillWidth: true
            }

            TextButton {
                visible: root.changedCount > 0
                text: Tr.tr("Reset all changes")
                type: TextButton.Text
                onClicked: resetAllDialog.ask({
                    header: Tr.tr("Reset all shortcut changes?"),
                    body: Tr.tr("Restore all %1 modified shortcut(s) back to their defaults?").arg(root.changedCount),
                    warning: Tr.tr("Your own custom shortcuts below will not be removed."),
                    confirmLabel: Tr.tr("Reset all"),
                    icon: "restart_alt",
                    onConfirm: () => root.resetAllChanges()
                })
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: root.sections.length === 0
            implicitHeight: emptyText.implicitHeight + Tokens.padding.large * 2

            StyledText {
                id: emptyText

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                horizontalAlignment: Text.AlignHCenter
                text: root.changedOnly ? Tr.tr("No shortcuts have been changed from their defaults.") : Tr.tr("No shortcuts match your search.")
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }
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

                        item: modelData
                    }
                }
            }
        }

        // The user's own: a key that runs a command
        SectionHeader {
            visible: !root.query && !root.changedOnly
            text: Tr.tr("Your own shortcuts")
        }

        Repeater {
            model: root.query || root.changedOnly ? [] : root.customBinds

            ConnectedRect {
                id: custom

                required property var modelData
                required property int index
                readonly property bool isEditing: root.editingCustomIndex === custom.index

                Layout.fillWidth: true
                implicitHeight: customLayout.implicitHeight + Tokens.padding.small * 2

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Item {
                    anchors.fill: parent
                    clip: true

                    ColumnLayout {
                        id: customLayout

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.small
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.small

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: customRow.implicitHeight

                            StateLayer {
                                anchors.fill: parent
                                topLeftRadius: custom.topLeftRadius
                                topRightRadius: custom.topRightRadius
                                bottomLeftRadius: custom.isEditing ? 0 : custom.bottomLeftRadius
                                bottomRightRadius: custom.isEditing ? 0 : custom.bottomRightRadius
                                disabled: custom.isEditing
                                onClicked: {
                                    root.editing = "";
                                    root.editingCustomIndex = custom.index;
                                }
                            }

                            RowLayout {
                                id: customRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.spacing.small

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
                                    icon: custom.isEditing ? "expand_less" : "edit"
                                    type: IconButton.Text
                                    onClicked: {
                                        root.editing = "";
                                        root.editingCustomIndex = custom.isEditing ? -1 : custom.index;
                                    }
                                }

                                IconButton {
                                    icon: "close"
                                    type: IconButton.Text
                                    onClicked: {
                                        root.editingCustomIndex = -1;
                                        const next = [...root.customBinds];
                                        next.splice(custom.index, 1);
                                        HyprSettings.setCustomBinds(next);
                                    }
                                }
                            }
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.rightMargin: Tokens.padding.medium
                            active: custom.isEditing
                            visible: active

                            sourceComponent: ColumnLayout {
                                spacing: Tokens.spacing.small

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.small

                                    StyledTextField {
                                        id: editCommandField

                                        Layout.fillWidth: true
                                        verticalPadding: Tokens.padding.small
                                        floatingPlaceholder: false
                                        text: custom.modelData.command
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
                                                    editCommandField.text = item.command;
                                            }
                                        })
                                    }
                                }

                                KeysEditor {
                                    Layout.fillWidth: true
                                    initial: custom.modelData.key
                                    acceptText: Tr.trCtx("Save", "button")
                                    cancellable: true
                                    acceptEnabled: editCommandField.text.trim().length > 0
                                    conflicts: root.findConflicts(keys, {
                                        kind: "custom",
                                        customIndex: custom.index
                                    })
                                    onAccepted: keys => root.saveCustom(keys, editCommandField.text, custom.index)
                                    onCancelled: root.editingCustomIndex = -1
                                }
                            }
                        }
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: !root.query && !root.changedOnly
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
                    onAccepted: keys => root.saveCustom(keys, commandField.text, -1)
                }
            }
        }

        ConfirmDialog {
            id: resetAllDialog

            hostFlickable: root.flickable
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
                        // Ones Replace can't turn off (built in, or set elsewhere,
                        // e.g. the magnifier keys): named, with where to change them
                        readonly property var keptOn: (conflictDialog.pendingAction?.conflicts ?? []).filter(c => !c.kind)
                        readonly property bool hasNonEditable: keptOn.length > 0
                        text: Tr.tr("%1 is already used by:\n• %2\n\nReplacing turns off the previous shortcut.").arg(root.prettyKeys(conflictDialog.pendingAction?.keys ?? "")).arg(listText) + (hasNonEditable ? "\n\n" + Tr.tr("These stay on (change them where they're set):\n• %1").arg(keptOn.map(c => c.reason ? `${c.label} — ${c.reason}` : c.label).join("\n• ")) : "")
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
                if (act.type === "custom") {
                    const next = [...root.customBinds];
                    if (act.editIndex >= 0 && act.editIndex < next.length)
                        next[act.editIndex] = {
                            key: act.keys,
                            command: act.command
                        };
                    const keptCustom = next.filter((_, idx) => !removedIdx.includes(idx));
                    if (!(act.editIndex >= 0))
                        keptCustom.push({
                            key: act.keys,
                            command: act.command
                        });
                    HyprSettings.setCustomBinds(keptCustom);
                    if (act.editIndex >= 0) {
                        root.editingCustomIndex = -1;
                    } else {
                        commandField.text = "";
                        addKeys.clear();
                    }
                } else {
                    const keptCustom = root.customBinds.filter((_, idx) => !removedIdx.includes(idx));
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
        Component.onCompleted: rebuildTimer.restart()

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

        FileView {
            id: keybindsFile

            path: `${root.hyprDir}/hyprland/keybinds.lua`
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

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            StateLayer {
                anchors.fill: parent
                topLeftRadius: srow.topLeftRadius
                topRightRadius: srow.topRightRadius
                bottomLeftRadius: srow.bottomLeftRadius
                bottomRightRadius: srow.bottomRightRadius
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
                            visible: srow.item.changed || !!srow.item.reason
                            text: srow.item.reason ? srow.item.reason : (srow.item.keys ? Tr.tr("Changed") : Tr.tr("Turned off"))
                            color: srow.item.reason ? Colours.palette.m3outline : Colours.palette.m3primary
                            font: Tokens.font.label.small
                            wrapMode: Text.WordWrap
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
}
