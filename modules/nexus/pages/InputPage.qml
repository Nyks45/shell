pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages.devices

// Keyboard (layouts, repeat), mouse, touchpad and cursor: Hyprland's input
// options, saved through HyprSettings.
PageBase {
    id: root

    // [{ code, name }] from XKB's layout list
    property var allLayouts: []
    // layoutCode -> [{ code, name }] from XKB's variant list
    property var variantsByLayout: ({})
    readonly property list<string> layouts: String(HyprSettings.value("input:kb_layout", "us")).split(",").map(s => s.trim()).filter(s => s)
    readonly property var variantList: String(HyprSettings.value("input:kb_variant", "")).split(",").map(s => s.trim())
    readonly property list<string> kbOptions: String(HyprSettings.value("input:kb_options", "")).split(",").map(s => s.trim()).filter(s => s)
    readonly property string switchOption: kbOptions.find(o => o.startsWith("grp:")) ?? ""

    property bool hasTouchpad
    property list<string> cursorThemes
    property string gsCursorTheme
    property int gsCursorSize: 24
    readonly property string cursorTheme: HyprSettings.varValue("cursorTheme", gsCursorTheme)
    readonly property int cursorSize: HyprSettings.varValue("cursorSize", gsCursorSize)

    function layoutName(code: string): string {
        return allLayouts.find(l => l.code === code)?.name ?? code;
    }

    function variantsFor(layoutCode: string): var {
        return variantsByLayout[layoutCode] ?? [];
    }

    function setLayouts(list: var): void {
        const prevLayouts = layouts;
        const nextVars = list.map(code => {
            const oldIdx = prevLayouts.indexOf(code);
            return oldIdx >= 0 ? (variantList[oldIdx] ?? "") : "";
        });
        HyprSettings.setOption("input:kb_layout", list.join(","));
        HyprSettings.setOption("input:kb_variant", nextVars.some(v => v) ? nextVars.join(",") : "");
        // Two layouts and no way to switch yet: Alt+Shift, like Windows
        if (list.length > 1 && !switchOption)
            setSwitch("grp:alt_shift_toggle");
    }

    function setVariant(slot: int, code: string): void {
        const next = [];
        for (let i = 0; i < layouts.length; i++)
            next.push(i === slot ? code : (variantList[i] ?? ""));
        HyprSettings.setOption("input:kb_variant", next.some(v => v) ? next.join(",") : "");
    }

    function setSwitch(option: string): void {
        const others = kbOptions.filter(o => !o.startsWith("grp:"));
        HyprSettings.setOption("input:kb_options", [...others, ...(option ? [option] : [])].join(","));
    }

    function setCursor(theme: string, size: int): void {
        gsCursorTheme = theme;
        gsCursorSize = size;
        HyprSettings.setVar("cursorTheme", theme);
        HyprSettings.setVar("cursorSize", size);
        // Now, not only at the next login
        Hypr.extras.message(`setcursor ${theme} ${size}`);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", String(size)]);
    }

    title: Tr.tr("Keyboard & mouse")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Keyboard
        SectionHeader {
            text: Tr.tr("Keyboard")
        }

        LayoutRow {
            icon: "keyboard"
            label: Tr.tr("Layout")
            status: root.layoutName(root.layouts[0] ?? "us")
            currentCode: root.layouts[0] ?? "us"
            onPicked: code => root.setLayouts([code, ...root.layouts.slice(1).filter(c => c !== code)])
        }

        SelectRow {
            visible: root.variantsFor(root.layouts[0] ?? "us").length > 0
            label: Tr.tr("Layout variant")
            segmentedAllowed: false
            menuItems: [defaultVar0, ...varItems0.instances]
            active: menuItems.find(i => i.value === (root.variantList[0] ?? "")) ?? defaultVar0
            onSelected: item => root.setVariant(0, String(item.value))

            MenuItem {
                id: defaultVar0

                text: Tr.tr("Default")
                value: ""
            }

            Variants {
                id: varItems0

                model: root.variantsFor(root.layouts[0] ?? "us")

                MenuItem {
                    required property var modelData

                    text: modelData.name
                    value: modelData.code
                }
            }
        }

        LayoutRow {
            icon: "translate"
            label: Tr.tr("Second layout")
            status: root.layouts.length > 1 ? root.layoutName(root.layouts[1]) : Tr.tr("None")
            allowNone: true
            currentCode: root.layouts.length > 1 ? root.layouts[1] : ""
            onPicked: code => root.setLayouts(code ? [root.layouts[0] ?? "us", code] : [root.layouts[0] ?? "us"])
        }

        SelectRow {
            visible: root.layouts.length > 1 && root.variantsFor(root.layouts[1] ?? "").length > 0
            label: Tr.tr("Second layout variant")
            segmentedAllowed: false
            menuItems: [defaultVar1, ...varItems1.instances]
            active: menuItems.find(i => i.value === (root.variantList[1] ?? "")) ?? defaultVar1
            onSelected: item => root.setVariant(1, String(item.value))

            MenuItem {
                id: defaultVar1

                text: Tr.tr("Default")
                value: ""
            }

            Variants {
                id: varItems1

                model: root.variantsFor(root.layouts[1] ?? "")

                MenuItem {
                    required property var modelData

                    text: modelData.name
                    value: modelData.code
                }
            }
        }

        SelectRow {
            visible: root.layouts.length > 1
            label: Tr.tr("Switch layouts with")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Alt + Shift")
                    value: "grp:alt_shift_toggle"
                },
                MenuItem {
                    text: Tr.tr("Super + Space")
                    value: "grp:win_space_toggle"
                },
                MenuItem {
                    text: Tr.tr("Ctrl + Shift")
                    value: "grp:ctrl_shift_toggle"
                },
                MenuItem {
                    text: Tr.tr("Caps Lock")
                    value: "grp:caps_toggle"
                }
            ]
            active: menuItems.find(i => i.value === root.switchOption) ?? null
            fallbackText: Tr.tr("Not set")
            onSelected: item => root.setSwitch(item.value)
        }

        StepperRow {
            label: Tr.tr("Repeat delay")
            subtext: Tr.tr("Wait time in milliseconds before a held key starts repeating")
            value: HyprSettings.value("input:repeat_delay", 600)
            from: 100
            to: 1000
            stepSize: 50
            onMoved: v => HyprSettings.setOption("input:repeat_delay", v)
        }

        StepperRow {
            label: Tr.tr("Repeat rate")
            subtext: Tr.tr("Characters repeated per second while holding a key")
            value: HyprSettings.value("input:repeat_rate", 25)
            from: 5
            to: 100
            stepSize: 5
            onMoved: v => HyprSettings.setOption("input:repeat_rate", v)
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: testRepeatField.implicitHeight + Tokens.padding.medium * 2

            StyledTextField {
                id: testRepeatField

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                leadingIcon: "keyboard"
                verticalPadding: Tokens.padding.small
                floatingPlaceholder: false
                placeholderText: Tr.tr("Hold down a key here to test repeat delay and speed")
            }
        }

        ToggleRow {
            text: Tr.tr("Num Lock on at login")
            checked: HyprSettings.value("input:numlock_by_default", false)
            onToggled: HyprSettings.setOption("input:numlock_by_default", checked)
        }

        // Mouse
        SectionHeader {
            text: Tr.tr("Mouse")
        }

        SliderRow {
            icon: "speed"
            label: Tr.tr("Pointer speed")
            valueLabel: {
                const s = HyprSettings.value("input:sensitivity", 0);
                return s === 0 ? Tr.tr("Default") : `${s > 0 ? "+" : ""}${Math.round(s * 100)}%`;
            }
            value: (HyprSettings.value("input:sensitivity", 0) + 1) / 2
            onMoved: v => HyprSettings.setOption("input:sensitivity", Math.round((v * 2 - 1) * 20) / 20)
        }

        ToggleRow {
            text: Tr.tr("Pointer acceleration")
            subtext: Tr.tr("Faster movements go further. Off: the pointer moves exactly with the mouse (better for games)")
            checked: HyprSettings.value("input:accel_profile", "") !== "flat"
            onToggled: HyprSettings.setOption("input:accel_profile", checked ? "adaptive" : "flat")
        }

        ToggleRow {
            text: Tr.tr("Natural scrolling")
            subtext: Tr.tr("Content follows the wheel, like on a phone")
            checked: HyprSettings.value("input:natural_scroll", false)
            onToggled: HyprSettings.setOption("input:natural_scroll", checked)
        }

        SliderRow {
            icon: "swap_vert"
            label: Tr.tr("Scroll speed")
            valueLabel: `${Math.round(HyprSettings.value("input:scroll_factor", 1) * 100)}%`
            // 25% .. 300%
            value: (HyprSettings.value("input:scroll_factor", 1) - 0.25) / 2.75
            onMoved: v => HyprSettings.setOption("input:scroll_factor", Math.round((0.25 + v * 2.75) * 20) / 20)
        }

        ToggleRow {
            text: Tr.tr("Swap left and right buttons")
            subtext: Tr.tr("For using the mouse with the left hand")
            checked: HyprSettings.value("input:left_handed", false)
            onToggled: HyprSettings.setOption("input:left_handed", checked)
        }

        // A Logitech gaming mouse's own settings (DPI, report rate, battery)
        GamingMouse {}

        // Touchpad
        SectionHeader {
            visible: root.hasTouchpad
            text: Tr.tr("Touchpad")
        }

        ToggleRow {
            visible: root.hasTouchpad
            text: Tr.tr("Tap to click")
            checked: HyprSettings.value("input:touchpad:tap-to-click", true)
            onToggled: HyprSettings.setOption("input:touchpad:tap-to-click", checked)
        }

        ToggleRow {
            visible: root.hasTouchpad
            text: Tr.tr("Natural scrolling")
            checked: HyprSettings.value("input:touchpad:natural_scroll", false)
            onToggled: HyprSettings.setOption("input:touchpad:natural_scroll", checked)
        }

        ToggleRow {
            visible: root.hasTouchpad
            text: Tr.tr("Turn off while typing")
            checked: HyprSettings.value("input:touchpad:disable_while_typing", true)
            onToggled: HyprSettings.setOption("input:touchpad:disable_while_typing", checked)
        }

        // Cursor
        SectionHeader {
            text: Tr.tr("Cursor")
        }

        SelectRow {
            label: Tr.tr("Cursor style")
            menuItems: themeItems.instances
            active: themeItems.instances.find(i => i.value === root.cursorTheme) ?? null
            fallbackText: root.cursorTheme
            onSelected: item => root.setCursor(item.value, root.cursorSize)

            Variants {
                id: themeItems

                model: root.cursorThemes

                MenuItem {
                    required property string modelData

                    text: modelData.replace(/[-_]/g, " ")
                    value: modelData
                }
            }
        }

        StepperRow {
            label: Tr.tr("Cursor size")
            value: root.cursorSize
            from: 16
            to: 96
            stepSize: 8
            onMoved: v => root.setCursor(root.cursorTheme, v)
        }

        SelectRow {
            label: Tr.tr("Hide the cursor when idle")
            subtext: Tr.tr("After the mouse hasn't moved for a while")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Never")
                    value: 0
                },
                MenuItem {
                    text: Tr.tr("After 3 seconds")
                    value: 3
                },
                MenuItem {
                    text: Tr.tr("After 5 seconds")
                    value: 5
                },
                MenuItem {
                    text: Tr.tr("After 10 seconds")
                    value: 10
                }
            ]
            active: menuItems.find(i => i.value === Math.round(HyprSettings.value("cursor:inactive_timeout", 0))) ?? null
            onSelected: item => HyprSettings.setOption("cursor:inactive_timeout", item.value)
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        FileView {
            path: "/usr/share/X11/xkb/rules/base.lst"
            printErrors: false
            onLoaded: {
                const raw = text();
                const section = raw.split(/^! layout\s*$/m)[1]?.split(/^!/m)[0] ?? "";
                // (not "custom": a placeholder for a user-made layout)
                root.allLayouts = section.split("\n").map(l => l.match(/^\s+(\S+)\s+(.+)$/)).filter(m => m && m[1] !== "custom").map(m => ({
                            code: m[1],
                            name: m[2].trim()
                        })).sort((a, b) => a.name.localeCompare(b.name));
                const varSection = raw.split(/^! variant\s*$/m)[1]?.split(/^!/m)[0] ?? "";
                const map = {};
                for (const line of varSection.split("\n")) {
                    const m = line.match(/^\s+(\S+)\s+(\S+):\s+(.+)$/);
                    if (!m)
                        continue;
                    if (!map[m[2]])
                        map[m[2]] = [];
                    map[m[2]].push({
                        code: m[1],
                        name: m[3].trim()
                    });
                }
                for (const k of Object.keys(map))
                    map[k].sort((a, b) => a.name.localeCompare(b.name));
                root.variantsByLayout = map;
            }
        }

        Process {
            running: true
            command: ["hyprctl", "-j", "devices"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.hasTouchpad = (JSON.parse(text).mice ?? []).some(m => /touchpad|trackpad/i.test(m.name));
                    } catch (e) {}
                }
            }
        }

        Process {
            running: true
            command: ["sh", "-c", "for d in \"$HOME/.icons\"/* \"$HOME/.local/share/icons\"/* /usr/share/icons/*; do [ -d \"$d/cursors\" ] && basename \"$d\"; done | sort -u"]
            stdout: StdioCollector {
                onStreamFinished: root.cursorThemes = text.split("\n").filter(s => s && s !== "default")
            }
        }

        Process {
            running: true
            command: ["sh", "-c", "gsettings get org.gnome.desktop.interface cursor-theme; gsettings get org.gnome.desktop.interface cursor-size"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [theme, size] = text.split("\n");
                    root.gsCursorTheme = (theme ?? "").trim().replace(/'/g, "");
                    root.gsCursorSize = parseInt(size) || 24;
                }
            }
        }
    }

    // A layout chosen from XKB's list
    component LayoutRow: PopupRow {
        id: row

        property bool allowNone
        property string currentCode
        property string query

        readonly property real rowH: Math.ceil(itemMetrics.height) + Tokens.padding.small * 2
        readonly property var baseLayouts: row.allowNone ? [{
                code: "",
                name: Tr.tr("None")
            }, ...root.allLayouts] : root.allLayouts
        readonly property var filteredLayouts: {
            const q = query.trim().toLowerCase();
            if (!q)
                return baseLayouts;
            return baseLayouts.filter(l => (l.name ?? "").toLowerCase().includes(q) || (l.code ?? "").toLowerCase().includes(q));
        }
        readonly property real listH: filteredLayouts.length > 0 ? Math.min(220, filteredLayouts.length * rowH + Math.max(0, filteredLayouts.length - 1) * 2) : 48

        signal picked(code: string)

        onOpenChanged: {
            if (open) {
                query = "";
                Qt.callLater(() => (popup.item as Item)?.forceActiveFocus());
            }
        }

        Connections {
            function onActiveChanged(): void {
                if (!row.popup.active)
                    row.query = "";
            }

            target: row.popup
        }

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popupWidth: 256
        popupHeight: rowH + Tokens.spacing.small + listH
        maxPopupHeight: 280

        FontMetrics {
            id: itemMetrics

            font: Tokens.font.body.small
        }

        popupContent: Component {
            ColumnLayout {
                id: popupCol

                spacing: Tokens.spacing.small
                onActiveFocusChanged: if (activeFocus)
                    filter.forceActiveFocus()

                SearchBar {
                    id: filter

                    Layout.fillWidth: true
                    implicitHeight: row.rowH
                    placeholderText: Tr.tr("Search layouts")
                    font: Tokens.font.body.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small
                    bg.color: Colours.tPalette.m3surfaceContainerLowest
                    bg.border.width: 1
                    bg.border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    onTextChanged: row.query = text
                    Keys.onEscapePressed: row.open = false
                    onAccepted: {
                        if (row.filteredLayouts.length > 0) {
                            row.open = false;
                            row.picked(row.filteredLayouts[0].code);
                        }
                    }

                    Connections {
                        function onQueryChanged(): void {
                            if (filter.text !== row.query)
                                filter.text = row.query;
                        }

                        target: row
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    VerticalFadeListView {
                        id: list

                        anchors.fill: parent
                        clip: true
                        fadeAmount: 0.08
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: row.filteredLayouts

                        delegate: StyledRect {
                            id: item

                            required property var modelData
                            readonly property bool current: modelData.code === row.currentCode

                            width: ListView.view.width
                            implicitHeight: row.rowH
                            radius: height / 2
                            color: current ? Colours.palette.m3secondaryContainer : "transparent"

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                onClicked: {
                                    row.open = false;
                                    row.picked(item.modelData.code);
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.medium
                                spacing: Tokens.spacing.medium

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: item.modelData.name
                                    font: Tokens.font.body.small
                                    color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: item.modelData.code
                                    color: item.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: row.filteredLayouts.length === 0
                        text: Tr.tr("No layouts match")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }
            }
        }
    }
}
