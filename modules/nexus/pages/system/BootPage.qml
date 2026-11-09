pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

// The boot menu (rEFInd): a preview of it as it shows, and everything about
// it to change: theme, background, each entry's icon, name, visibility and
// place, the tools shown, sizes, the countdown and default, Linux options.
// Changes are a draft shown in the preview first; Apply writes them all at
// once (one password prompt, through caelestia-admin boot-apply). Also:
// restart into Windows once, UEFI boot entries, Secure Boot, firmware.
PageBase {
    id: root

    // caelestia-system boot / firmware
    property var boot: null
    property var fw: null
    // The draft and what it started from (see makeDraft)
    property var draft: null
    property var start: null
    // An entry being changed (its editor below the list open)
    property string editing
    readonly property int editIndex: draft ? draft.entries.findIndex(e => e.name === editing) : -1
    readonly property var editEntry: editIndex >= 0 ? draft.entries[editIndex] : null
    readonly property bool dirty: !!draft && JSON.stringify(draft) !== JSON.stringify(start)
    readonly property string applyWhat: Tr.tr("Change the boot menu")
    readonly property bool applying: Admin.jobs.some(j => j.what === applyWhat)

    readonly property var toolIcons: ({
            shutdown: "func_shutdown",
            reboot: "func_reset",
            firmware: "func_firmware",
            about: "func_about",
            exit: "func_exit",
            hidden_tags: "func_hidden",
            bootorder: "func_bootorder",
            memtest: "tool_memtest",
            shell: "tool_shell",
            mok_tool: "tool_mok_tool",
            windows_recovery: "tool_windows_rescue"
        })
    readonly property var toolNames: [["shutdown", Tr.tr("Shut down")], ["reboot", Tr.tr("Restart")], ["firmware", Tr.tr("Firmware settings (UEFI)")], ["hidden_tags", Tr.tr("Hidden entries")], ["bootorder", Tr.tr("UEFI boot order")], ["about", Tr.tr("About rEFInd")], ["exit", Tr.tr("Leave rEFInd")], ["memtest", Tr.tr("Memory test")], ["shell", Tr.tr("EFI shell")], ["mok_tool", Tr.tr("Secure Boot keys (MOK)")], ["windows_recovery", Tr.tr("Windows recovery")]]
    // hideui items people care about: shown when not hidden
    readonly property var uiParts: [["label", Tr.tr("Entry names"), Tr.tr("The chosen entry's name under the icons")], ["hints", Tr.tr("Keyboard hints"), Tr.tr("The help text at the bottom")], ["banner", Tr.tr("Background picture"), Tr.tr("Off: a plain black screen")], ["badges", Tr.tr("Disk badges"), Tr.tr("A small icon of the disk on each entry")], ["arrows", Tr.tr("Scroll arrows"), Tr.tr("When there are more entries than fit")], ["editor", Tr.tr("Options editor"), Tr.tr("Changing an entry's options before booting (F2)")]]
    readonly property var flavourNames: [["mocha", "Mocha"], ["macchiato", "Macchiato"], ["frappe", "Frappé"], ["latte", Tr.tr("Latte (light)")]]
    readonly property var optionToggles: [["quiet", Tr.tr("Quiet start"), Tr.tr("Fewer messages while Linux starts")], ["splash", Tr.tr("Splash screen"), Tr.tr("A picture instead of text while starting")], ["nowatchdog", Tr.tr("No watchdog"), Tr.tr("Slightly faster start and shutdown")]]

    function load(): void {
        bootProc.running = true;
        fwProc.running = true;
    }

    function makeDraft(b: var): var {
        const opts = (b.options || "").split(/\s+/).filter(o => o);
        return {
            timeout: b.timeout,
            defaultSelection: b.defaultSelection,
            flavour: b.flavour || "mocha",
            bgMode: "keep",
            bgFile: "",
            big: b.bigIconSize,
            small: b.smallIconSize,
            tools: b.showtools.map(t => t.tool),
            hideui: b.hideui,
            entries: b.entries.map(e => ({
                        name: e.name,
                        newName: e.name,
                        iconSpec: e.iconSpec,
                        iconFile: e.iconFile,
                        hidden: !!e.hidden,
                        snapshots: e.submenus.length,
                        kernels: e.kernels
                    })),
            options: opts
        };
    }

    function change(f: var): void {
        const d = JSON.parse(JSON.stringify(draft));
        f(d);
        draft = d;
    }

    function iconFile(spec: string, flavour: string, fallback: string): string {
        if (!spec || !boot)
            return fallback;
        const i = spec.indexOf(":");
        const kind = spec.slice(0, i);
        const name = spec.slice(i + 1);
        if (kind === "theme")
            return `${boot.flavours[flavour]?.iconsDir ?? ""}/${name}`;
        if (kind === "stock")
            return `${boot.stockDir}/${name}`;
        if (kind === "local")
            return `${boot.localDir}/${name}`;
        if (kind === "file")
            return name;
        return fallback;
    }

    function toolFile(tool: string, flavour: string): string {
        const n = toolIcons[tool];
        if (!n || !boot)
            return "";
        const own = `${boot.flavours[flavour]?.iconsDir ?? ""}/${n}.png`;
        return (boot.flavours[flavour]?.icons ?? []).includes(`${n}.png`) ? own : `${boot.stockDir}/${n}.png`;
    }

    // What the preview draws: the draft resolved to files
    readonly property var previewModel: {
        if (!draft || !boot)
            return null;
        const fl = boot.flavours[draft.flavour] ?? {};
        let bg = boot.banner;
        if (draft.bgMode === "file")
            bg = draft.bgFile;
        else if (draft.bgMode === "theme" || (bg && bg.includes("/themes/catppuccin/assets/")))
            bg = fl.background ?? bg;
        return {
            background: bg,
            selectionBig: fl.selectionBig ?? boot.selectionBig,
            bigIconSize: draft.big,
            smallIconSize: draft.small,
            hideui: draft.hideui,
            tools: draft.tools.map(t => ({
                        tool: t,
                        iconFile: toolFile(t, draft.flavour)
                    })),
            entries: draft.entries.map(e => ({
                        name: e.newName || e.name,
                        iconFile: iconFile(e.iconSpec, draft.flavour, e.iconFile),
                        hidden: e.hidden
                    })),
            selected: draft.defaultSelection === "+" ? "" : draft.defaultSelection
        };
    }

    // The draft's changes for boot-apply
    function payload(): var {
        const p = {
            set: {}
        };
        if (draft.timeout !== start.timeout)
            p.set.timeout = draft.timeout;
        if (draft.defaultSelection !== start.defaultSelection && draft.defaultSelection)
            p.set.default_selection = draft.defaultSelection;
        if (draft.big !== start.big)
            p.set.big_icon_size = draft.big;
        if (draft.small !== start.small)
            p.set.small_icon_size = draft.small;
        if (JSON.stringify(draft.tools) !== JSON.stringify(start.tools))
            p.set.showtools = draft.tools;
        if (JSON.stringify(draft.hideui) !== JSON.stringify(start.hideui))
            p.set.hideui = draft.hideui;
        if (draft.flavour !== start.flavour)
            p.theme = draft.flavour;
        if (draft.bgMode === "file")
            p.background = draft.bgFile;
        else if (draft.bgMode === "theme")
            p.background = "--theme";
        p.entries = [];
        for (const e of draft.entries) {
            const s = start.entries.find(x => x.name === e.name);
            const c = {
                name: e.name
            };
            if (e.newName !== s.newName)
                c.newName = e.newName;
            if (e.iconSpec !== s.iconSpec)
                c.icon = e.iconSpec;
            if (e.hidden !== s.hidden)
                c.visible = !e.hidden;
            if (Object.keys(c).length > 1)
                p.entries.push(c);
        }
        const order = draft.entries.map(e => e.name);
        if (JSON.stringify(order) !== JSON.stringify(start.entries.map(e => e.name)))
            p.order = order;
        if (JSON.stringify(draft.options) !== JSON.stringify(start.options))
            p.options = draft.options;
        return p;
    }

    function apply(): void {
        Admin.exec(["pkexec", Admin.helper, "boot-apply"], applyWhat, ok => {
            if (ok)
                root.load();
        }, JSON.stringify(payload()));
    }

    title: Tr.tr("Boot menu")

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Not set up yet: the ESP is root-only
        InfoRow {
            visible: !!root.boot && !root.boot.setup
            icon: "visibility"
            label: root.boot?.exported ? Tr.tr("Keep this preview current") : Tr.tr("See and change your boot menu here")
            subtext: Tr.tr("Once: lets the settings read the boot menu (it's only readable by the system), keeps that copy current, and adds new kernels to the menu")
        }

        RowButton {
            Layout.fillWidth: true
            visible: !!root.boot && !root.boot.setup
            icon: "settings"
            text: Tr.tr("Set up")
            subtext: Tr.tr("Asks for your password")
            onClicked: Admin.run("boot-setup", [], Tr.tr("Set up the boot menu settings"), () => root.load())
        }

        // The preview
        StyledRect {
            Layout.fillWidth: true
            visible: !!root.previewModel
            implicitHeight: preview.implicitHeight
            radius: Tokens.rounding.large
            clip: true
            color: "black"

            BootPreview {
                id: preview

                anchors.left: parent.left
                anchors.right: parent.right
                draft: root.previewModel
                // rEFInd draws at the monitor's size: the widest screen (a
                // portrait or nested one falls back to 2560x1440)
                readonly property var screen: [...Quickshell.screens].sort((a, b) => b.width - a.width)[0] ?? null
                readonly property bool landscape: !!screen && screen.width > screen.height
                screenWidth: landscape ? screen.width : 2560
                screenHeight: landscape ? screen.height : 1440
                onEntryClicked: name => root.editing = root.draft.entries.find(e => (e.newName || e.name) === name)?.name ?? ""
            }

            StyledText {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.padding.large
                visible: root.dirty
                text: Tr.tr("Preview of your changes")
                color: "white"
                font: Tokens.font.label.small

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Tokens.padding.small
                    z: -1
                    radius: Tokens.rounding.full
                    color: Qt.rgba(0, 0, 0, 0.55)
                }
            }
        }

        // Apply / undo the draft
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.dirty || root.applying
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.applying ? Tr.tr("Writing the boot menu…") : Tr.tr("Not written yet: the preview shows what it will look like")
                color: Colours.palette.m3primary
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            TextButton {
                visible: !root.applying
                text: Tr.tr("Undo changes")
                type: TextButton.Text
                onClicked: root.draft = JSON.parse(JSON.stringify(root.start))
            }

            TextButton {
                visible: !root.applying
                text: Tr.tr("Apply")
                type: TextButton.Filled
                onClicked: root.apply()
            }
        }

        // Look
        SectionHeader {
            visible: !!root.draft
            text: Tr.tr("Look")
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.draft
            spacing: Tokens.spacing.small

            Repeater {
                model: root.flavourNames.filter(f => !!root.boot?.flavours?.[f[0]])

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.draft?.flavour === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.change(d => d.flavour = modelData[0])
                }
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: !!root.draft
            icon: "image"
            text: Tr.tr("Background: your picture…")
            subtext: root.draft?.bgMode === "file" ? root.draft.bgFile : root.boot?.banner?.includes("/themes/local/") && root.draft?.bgMode === "keep" ? Tr.tr("Your picture now") : Tr.tr("Choose a picture (shown in the preview first)")
            onClicked: bgPicker.open()
        }

        RowButton {
            Layout.fillWidth: true
            visible: !!root.draft
            icon: "wallpaper"
            text: Tr.tr("Background: the theme's own")
            subtext: root.draft?.bgMode === "theme" || (root.draft?.bgMode === "keep" && !root.boot?.banner?.includes("/themes/local/")) ? Tr.tr("In use") : ""
            onClicked: root.change(d => {
                d.bgMode = "theme";
                d.bgFile = "";
            })
        }

        StepperRow {
            visible: !!root.draft
            label: Tr.tr("Entry icon size")
            subtext: Tr.tr("Pixels")
            from: 64
            to: 384
            stepSize: 16
            value: root.draft?.big ?? 128
            onMoved: v => root.change(d => d.big = v)
        }

        StepperRow {
            visible: !!root.draft
            label: Tr.tr("Tool icon size")
            subtext: Tr.tr("Pixels")
            from: 32
            to: 128
            stepSize: 8
            value: root.draft?.small ?? 48
            onMoved: v => root.change(d => d.small = v)
        }

        // Entries
        SectionHeader {
            visible: !!root.draft
            text: Tr.tr("Entries")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.draft
            text: Tr.tr("Click an icon in the preview or an entry here to change its icon, name and place.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        // The entries (sibling rows), then the editor of the chosen one
        Repeater {
            model: root.draft?.entries ?? []

            RowButton {
                required property var modelData

                Layout.fillWidth: true
                icon: modelData.hidden ? "visibility_off" : "label"
                text: modelData.newName || modelData.name
                subtext: [modelData.hidden ? Tr.tr("hidden") : "", modelData.snapshots > 0 ? Tr.tr("%1 snapshots inside").arg(modelData.snapshots) : "", (modelData.kernels ?? []).length > 0 ? Tr.tr("other kernels inside") : ""].filter(s => s).join(" · ")
                trailingIcon: root.editing === modelData.name ? "edit" : "chevron_right"
                onClicked: root.editing = root.editing === modelData.name ? "" : modelData.name
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            visible: root.editIndex >= 0
            spacing: Tokens.spacing.extraSmall / 2

            StyledText {
                Layout.leftMargin: Tokens.padding.small
                Layout.bottomMargin: Tokens.spacing.small
                text: Tr.tr("Changing %1").arg(root.editEntry?.newName || root.editEntry?.name || "")
                color: Colours.palette.m3primary
                font: Tokens.font.label.medium
            }

            TextFieldRow {
                label: Tr.tr("Name")
                value: root.editEntry?.newName ?? ""
                onValueEdited: v => root.change(d => d.entries[root.editIndex].newName = v.replace(/[^A-Za-z0-9 ._()+-]/g, ""))
            }

            ToggleRow {
                text: Tr.tr("Show it in the menu")
                checked: !(root.editEntry?.hidden ?? false)
                onToggled: root.change(d => d.entries[root.editIndex].hidden = !checked)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                TextButton {
                    enabled: root.editIndex > 0
                    text: Tr.tr("Move left")
                    type: TextButton.Tonal
                    onClicked: root.change(d => {
                        const e = d.entries.splice(root.editIndex, 1)[0];
                        d.entries.splice(root.editIndex - 1, 0, e);
                    })
                }

                TextButton {
                    enabled: root.editIndex < (root.draft?.entries.length ?? 0) - 1
                    text: Tr.tr("Move right")
                    type: TextButton.Tonal
                    onClicked: root.change(d => {
                        const e = d.entries.splice(root.editIndex, 1)[0];
                        d.entries.splice(root.editIndex + 1, 0, e);
                    })
                }

                TextButton {
                    text: Tr.tr("Own picture…")
                    type: TextButton.Tonal
                    onClicked: {
                        iconPicker.entryIndex = root.editIndex;
                        iconPicker.open();
                    }
                }
            }

            StyledText {
                Layout.topMargin: Tokens.spacing.small
                text: Tr.tr("Icon")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            // Every icon to choose from, by where it comes from: the
            // theme's (in the draft's flavour), yours, rEFInd's own
            Repeater {
                model: [[Tr.tr("Theme (%1)").arg(root.draft?.flavour ?? ""), (root.boot?.flavours?.[root.draft?.flavour]?.icons ?? []).filter(i => i.startsWith("os_")).map(i => `theme:${i}`)], [Tr.tr("Yours"), (root.boot?.localIcons ?? []).map(i => `local:${i}`)], [Tr.tr("rEFInd's own"), (root.boot?.stockIcons ?? []).map(i => `stock:${i}`)]].filter(g => g[1].length > 0)

                ColumnLayout {
                    id: group

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: `${group.modelData[0]} · ${group.modelData[1].length}`
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: group.modelData[1]

                            StyledRect {
                                id: choice

                                required property string modelData

                                readonly property bool chosen: root.editEntry?.iconSpec === modelData

                                implicitWidth: 56
                                implicitHeight: 56
                                radius: Tokens.rounding.small
                                color: chosen ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

                                Image {
                                    anchors.centerIn: parent
                                    width: 40
                                    height: 40
                                    source: `file://${root.iconFile(choice.modelData, root.draft?.flavour ?? "mocha", "")}`
                                    sourceSize.width: 80
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                StateLayer {
                                    onClicked: root.change(d => d.entries[root.editIndex].iconSpec = choice.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // What the menu shows
        SectionHeader {
            visible: !!root.draft
            text: Tr.tr("What the menu shows")
        }

        Repeater {
            model: root.draft ? root.uiParts : []

            ToggleRow {
                required property var modelData

                text: modelData[1]
                subtext: modelData[2]
                checked: !root.draft.hideui.includes(modelData[0])
                onToggled: root.change(d => d.hideui = checked ? d.hideui.filter(h => h !== modelData[0]) : [...d.hideui, modelData[0]])
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.draft
            text: Tr.tr("Tool buttons (the small icons)")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.boot?.toolsByDefault && JSON.stringify(root.draft?.tools) === JSON.stringify(root.start?.tools)
            text: Tr.tr("Now: rEFInd's default tools, plus the theme's shut-down button again (it shows twice). Choose the ones you want here; Apply writes just those.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3primary
            font: Tokens.font.label.small
        }

        // Each tool as it shows in the menu: its icon (the theme's, else
        // rEFInd's own) on the menu's dark background; a tap turns it on/off
        Flow {
            Layout.fillWidth: true
            visible: !!root.draft
            spacing: Tokens.spacing.small

            Repeater {
                model: root.draft ? root.toolNames : []

                StyledRect {
                    id: tool

                    required property var modelData

                    readonly property bool on: root.draft.tools.includes(modelData[0])

                    implicitWidth: 112
                    implicitHeight: toolCol.implicitHeight + Tokens.padding.medium * 2
                    radius: Tokens.rounding.medium
                    color: on ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

                    ColumnLayout {
                        id: toolCol

                        anchors.centerIn: parent
                        width: parent.width - Tokens.padding.medium * 2
                        spacing: Tokens.spacing.small

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 52
                            implicitHeight: 52
                            radius: Tokens.rounding.small
                            color: "#11111b"

                            Image {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                source: `file://${root.toolFile(tool.modelData[0], root.draft?.flavour ?? "mocha")}`
                                sourceSize.width: 72
                                fillMode: Image.PreserveAspectFit
                                opacity: tool.on ? 1 : 0.45
                                asynchronous: true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: tool.modelData[1]
                            wrapMode: Text.WordWrap
                            color: tool.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }

                    MaterialIcon {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Tokens.padding.small
                        visible: tool.on
                        text: "check_circle"
                        fill: 1
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StateLayer {
                        // one clean list, each tool once, in the menu's order
                        onClicked: root.change(d => d.tools = root.toolNames.map(t => t[0]).filter(t => t === tool.modelData[0] ? !tool.on : d.tools.includes(t)))
                    }
                }
            }
        }

        // Starting
        SectionHeader {
            visible: !!root.draft
            text: Tr.tr("Starting")
        }

        StepperRow {
            visible: !!root.draft
            label: Tr.tr("Countdown")
            subtext: (root.draft?.timeout ?? 0) === 0 ? Tr.tr("Waits until you choose") : Tr.tr("Seconds before the default starts")
            from: 0
            to: 60
            value: root.draft?.timeout ?? 5
            onMoved: v => root.change(d => d.timeout = v)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.draft
            text: Tr.tr("Starts by default")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        Flow {
            Layout.fillWidth: true
            visible: !!root.draft
            spacing: Tokens.spacing.small

            Repeater {
                model: root.draft ? [["+", Tr.tr("The one started last")], ...root.draft.entries.filter(e => !e.hidden).map(e => [e.newName || e.name, e.newName || e.name])] : []

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: (root.draft.defaultSelection || "+") === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.change(d => d.defaultSelection = modelData[0])
                }
            }
        }

        // Linux options
        SectionHeader {
            visible: !!root.draft && (root.draft.options.length > 0)
            text: Tr.tr("Linux start options")
        }

        Repeater {
            model: root.draft && root.draft.options.length > 0 ? root.optionToggles : []

            ToggleRow {
                required property var modelData

                text: modelData[1]
                subtext: modelData[2]
                checked: root.draft.options.includes(modelData[0])
                onToggled: root.change(d => d.options = checked ? [...d.options, modelData[0]] : d.options.filter(o => o !== modelData[0]))
            }
        }

        TextFieldRow {
            visible: !!root.draft && root.draft.options.length > 0
            label: Tr.tr("All options")
            subtext: Tr.tr("root=, rw and rootflags= must stay")
            value: root.draft?.options.join(" ") ?? ""
            onEditingFinished: v => {
                const opts = v.split(/\s+/).filter(o => o && /^[A-Za-z0-9_.,=:\/@+-]+$/.test(o));
                if (opts.some(o => o.startsWith("root=")) && opts.includes("rw"))
                    root.change(d => d.options = opts);
            }
        }

        // Firmware (immediate, not part of the draft)
        SectionHeader {
            visible: !!root.fw
            text: Tr.tr("Firmware")
        }

        DialogRowButton {
            id: winDialog

            readonly property var win: root.fw?.entries.find(e => /windows/i.test(e.label)) ?? null

            visible: !!win
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 260)
            icon: "restart_alt"
            label: Tr.tr("Restart into Windows")
            header: Tr.tr("Restart into Windows now?")
            acceptLabel: Tr.tr("Restart")
            content: Component {
                StyledText {
                    text: Tr.tr("The next start goes straight to Windows (once); after that the boot menu is back. Save your work first.")
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
            onAccepted: Admin.run("efi-bootnext", [win.num], Tr.tr("Restart into Windows"), ok => {
                if (ok)
                    Quickshell.execDetached(["systemctl", "reboot"]);
            })
        }

        InfoRow {
            visible: !!root.fw
            icon: root.fw?.secureBoot === 1 ? "verified_user" : "shield"
            label: Tr.tr("Secure Boot")
            value: root.fw?.secureBoot === 1 ? Tr.tr("On") : root.fw?.secureBoot === 0 ? Tr.tr("Off") : Tr.tr("Unknown")
            subtext: root.fw?.secureBoot === 1 ? Tr.tr("Kernels installed here are signed for it (sbctl)") : ""
        }

        InfoRow {
            visible: !!root.fw
            icon: "list"
            label: Tr.tr("UEFI boot order")
            subtext: (root.fw?.order ?? []).map(n => root.fw.entries.find(e => e.num === n)?.label ?? n).join("  →  ")
        }

        RowButton {
            Layout.fillWidth: true
            visible: !!root.fw && !root.fw.fwupd
            icon: "memory"
            text: Tr.tr("Firmware updates")
            subtext: Tr.tr("Updates for the motherboard, SSD and devices (fwupd): install it")
            onClicked: Packages.install({
                source: "repo",
                name: "fwupd"
            }, () => root.load())
        }

        FileDialog {
            id: bgPicker

            title: Tr.tr("A picture for the boot menu")
            filterLabel: Tr.tr("Pictures")
            filters: ["png", "jpg", "jpeg", "webp", "bmp"]
            onAccepted: path => root.change(d => {
                d.bgMode = "file";
                d.bgFile = path;
            })
        }

        FileDialog {
            id: iconPicker

            property int entryIndex

            title: Tr.tr("A picture as the entry's icon")
            filterLabel: Tr.tr("Pictures")
            filters: ["png", "jpg", "jpeg", "webp"]
            onAccepted: path => root.change(d => d.entries[iconPicker.entryIndex].iconSpec = `file:${path}`)
        }

        Process {
            id: bootProc

            command: [`${Paths.libdir}/caelestia-system`, "boot"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.boot = JSON.parse(text);
                        if (root.boot.exported) {
                            root.start = root.makeDraft(root.boot);
                            root.draft = JSON.parse(JSON.stringify(root.start));
                        }
                    } catch (e) {}
                }
            }
        }

        Process {
            id: fwProc

            command: [`${Paths.libdir}/caelestia-system`, "firmware"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.fw = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}
