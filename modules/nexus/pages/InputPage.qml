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

// Keyboard (layouts, repeat), mouse, touchpad and cursor: Hyprland's input
// options, saved through HyprSettings.
PageBase {
    id: root

    // [{ code, name }] from XKB's layout list
    property var allLayouts: []
    readonly property list<string> layouts: String(HyprSettings.value("input:kb_layout", "us")).split(",").map(s => s.trim()).filter(s => s)
    readonly property list<string> kbOptions: String(HyprSettings.value("input:kb_options", "")).split(",").map(s => s.trim()).filter(s => s)
    readonly property string switchOption: kbOptions.find(o => o.startsWith("grp:")) ?? ""

    property bool hasTouchpad
    property list<string> cursorThemes
    property string cursorTheme
    property int cursorSize: 24

    function layoutName(code: string): string {
        return allLayouts.find(l => l.code === code)?.name ?? code;
    }

    function setLayouts(list: var): void {
        HyprSettings.setOption("input:kb_layout", list.join(","));
        // Two layouts and no way to switch yet: Alt+Shift, like Windows
        if (list.length > 1 && !switchOption)
            setSwitch("grp:alt_shift_toggle");
    }

    function setSwitch(option: string): void {
        const others = kbOptions.filter(o => !o.startsWith("grp:"));
        HyprSettings.setOption("input:kb_options", [...others, ...(option ? [option] : [])].join(","));
    }

    function setCursor(theme: string, size: int): void {
        cursorTheme = theme;
        cursorSize = size;
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
            first: true
            text: Tr.tr("Keyboard")
        }

        LayoutRow {
            first: true
            icon: "keyboard"
            label: Tr.tr("Layout")
            status: root.layoutName(root.layouts[0] ?? "us")
            onPicked: code => root.setLayouts([code, ...root.layouts.slice(1).filter(c => c !== code)])
        }

        LayoutRow {
            icon: "translate"
            label: Tr.tr("Second layout")
            status: root.layouts.length > 1 ? root.layoutName(root.layouts[1]) : Tr.tr("None")
            allowNone: true
            onPicked: code => root.setLayouts(code ? [root.layouts[0] ?? "us", code] : [root.layouts[0] ?? "us"])
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
            subtext: Tr.tr("How long a key is held before it repeats (ms)")
            value: HyprSettings.value("input:repeat_delay", 600)
            from: 100
            to: 1000
            stepSize: 50
            onMoved: v => HyprSettings.setOption("input:repeat_delay", v)
        }

        StepperRow {
            label: Tr.tr("Repeat rate")
            subtext: Tr.tr("Characters per second while a key repeats")
            value: HyprSettings.value("input:repeat_rate", 25)
            from: 5
            to: 100
            stepSize: 5
            onMoved: v => HyprSettings.setOption("input:repeat_rate", v)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Num Lock on at login")
            checked: HyprSettings.value("input:numlock_by_default", false)
            onToggled: HyprSettings.setOption("input:numlock_by_default", checked)
        }

        // Mouse
        SectionHeader {
            text: Tr.tr("Mouse")
        }

        SliderRow {
            first: true
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
            last: true
            text: Tr.tr("Swap left and right buttons")
            subtext: Tr.tr("For using the mouse with the left hand")
            checked: HyprSettings.value("input:left_handed", false)
            onToggled: HyprSettings.setOption("input:left_handed", checked)
        }

        // Touchpad
        SectionHeader {
            visible: root.hasTouchpad
            text: Tr.tr("Touchpad")
        }

        ToggleRow {
            visible: root.hasTouchpad
            first: true
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
            last: true
            text: Tr.tr("Turn off while typing")
            checked: HyprSettings.value("input:touchpad:disable_while_typing", true)
            onToggled: HyprSettings.setOption("input:touchpad:disable_while_typing", checked)
        }

        // Cursor
        SectionHeader {
            text: Tr.tr("Cursor")
        }

        SelectRow {
            first: true
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
            last: true
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
                const section = text().split(/^! layout\s*$/m)[1]?.split(/^!/m)[0] ?? "";
                // (not "custom": a placeholder for a user-made layout)
            root.allLayouts = section.split("\n").map(l => l.match(/^\s+(\S+)\s+(.+)$/)).filter(m => m && m[1] !== "custom").map(m => ({
                            code: m[1],
                            name: m[2].trim()
                        })).sort((a, b) => a.name.localeCompare(b.name));
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
                    root.cursorTheme = HyprSettings.varValue("cursorTheme", (theme ?? "").replace(/'/g, ""));
                    root.cursorSize = HyprSettings.varValue("cursorSize", parseInt(size) || 24);
                }
            }
        }
    }

    // A layout chosen from XKB's list
    component LayoutRow: PopupRow {
        id: row

        property bool allowNone
        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        signal picked(code: string)

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                // As tall as its items (a short list doesn't get an empty tail), up to the usual height
                implicitHeight: Math.min(contentHeight + topMargin + bottomMargin, CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight))

                model: row.allowNone ? [{
                        code: "",
                        name: Tr.tr("None")
                    }, ...root.allLayouts] : root.allLayouts

                delegate: StateLayer {
                    id: item

                    required property var modelData

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: itemLayout.implicitHeight + itemLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        row.picked(modelData.code);
                    }

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: item.modelData.code
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }
    }
}
