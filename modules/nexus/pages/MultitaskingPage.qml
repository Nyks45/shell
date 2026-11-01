pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Focus and workspaces (Hyprland options; focus is set apart for desktop mode
// and the scrolling layout), and rules for how particular apps' windows open.
PageBase {
    id: root

    readonly property bool hyprflowLoaded: HyprSettings.values["plugin:hyprflow:bar_enabled"] !== undefined
    readonly property var rules: HyprSettings.saved.windowRules ?? []
    property int openRule: -1

    // Classes of the windows open now, for picking an app
    readonly property list<string> openClasses: [...new Set(Hyprland.toplevels.values.map(t => t.lastIpcObject?.class ?? "").filter(c => c))].sort()

    // The scrolling layout (hyprscroller)
    readonly property bool scrollerLoaded: HyprSettings.values["plugin:hyprscrolling:column_width"] !== undefined

    function sc(name: string, fallback: var): var {
        return HyprSettings.value(`plugin:hyprscrolling:${name}`, fallback);
    }

    function setSc(name: string, val: var): void {
        HyprSettings.setOption(`plugin:hyprscrolling:${name}`, val);
    }

    function setRule(index: int, changes: var): void {
        const next = rules.map(r => Object.assign({}, r));
        Object.assign(next[index], changes);
        HyprSettings.setWindowRules(next);
    }

    function removeRule(index: int): void {
        const next = [...rules];
        next.splice(index, 1);
        openRule = -1;
        HyprSettings.setWindowRules(next);
    }

    function addRule(cls: string): void {
        const escaped = cls.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const index = rules.length;
        HyprSettings.setWindowRules([...rules, {
                class: `^(${escaped})$`,
                float: true
            }]);
        openRule = index; // the new one, open to edit
    }

    title: Tr.tr("Workspaces & focus")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Focus")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Focus follows the mouse")
            subtext: Tr.tr("In the scrolling layout: the window under the pointer gets the keyboard")
            checked: HyprSettings.modeValue("tiling", "input:follow_mouse", 1) === 1
            onToggled: HyprSettings.setModeOption("tiling", "input:follow_mouse", checked ? 1 : 0)
        }

        ToggleRow {
            text: Tr.tr("Focus follows the mouse in desktop mode")
            disabled: !root.hyprflowLoaded
            subtext: root.hyprflowLoaded ? Tr.tr("Off: click a window to use it, like Windows") : Tr.tr("Needs the hyprflow plugin (desktop mode)")
            checked: HyprSettings.modeValue("desktop", "input:follow_mouse", 2) === 1
            onToggled: HyprSettings.setModeOption("desktop", "input:follow_mouse", checked ? 1 : 2)
        }

        ToggleRow {
            text: Tr.tr("Bring windows forward when they ask")
            subtext: Tr.tr("E.g. a link opened from another app focuses the browser")
            checked: HyprSettings.value("misc:focus_on_activate", true)
            onToggled: HyprSettings.setOption("misc:focus_on_activate", checked)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Move the pointer with the focus")
            subtext: Tr.tr("When the keyboard switches windows, the pointer jumps to the new one")
            checked: !HyprSettings.value("cursor:no_warps", false)
            onToggled: HyprSettings.setOption("cursor:no_warps", !checked)
        }

        SectionHeader {
            text: Tr.tr("Workspaces")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Go back with the same key")
            subtext: Tr.tr("Pressing the shortcut of the workspace you're on goes to the one before")
            checked: HyprSettings.value("binds:workspace_back_and_forth", false)
            onToggled: HyprSettings.setOption("binds:workspace_back_and_forth", checked)
        }

        ToggleRow {
            text: Tr.tr("Open apps where they were started")
            subtext: Tr.tr("An app that takes a while opens on the workspace it was started from")
            checked: HyprSettings.value("misc:initial_workspace_tracking", 1) > 0
            onToggled: HyprSettings.setOption("misc:initial_workspace_tracking", checked ? 1 : 0)
        }

        SelectRow {
            last: true
            label: Tr.tr("New window over a fullscreen one")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Opens behind it")
                    value: 0
                },
                MenuItem {
                    text: Tr.tr("Takes over fullscreen")
                    value: 1
                },
                MenuItem {
                    text: Tr.tr("Ends fullscreen")
                    value: 2
                }
            ]
            active: menuItems.find(i => i.value === HyprSettings.value("misc:new_window_takes_over_fullscreen", 0)) ?? null
            onSelected: item => HyprSettings.setOption("misc:new_window_takes_over_fullscreen", item.value)
        }

        // The scrolling layout: columns of windows side by side, scrolled through
        SectionHeader {
            text: Tr.tr("Scrolling layout")
        }

        RequirementRow {
            visible: !root.scrollerLoaded
            first: true
            last: true
            text: Tr.tr("Needs the hyprscroller plugin")
            subtext: Tr.tr("The scrolling layout (columns side by side) comes from hyprscroller, which isn't loaded.")
            actionText: Tr.tr("Plugins")
            onAction: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "plugins"),
                path: []
            })
        }

        SliderRow {
            visible: root.scrollerLoaded
            first: true
            icon: "view_column"
            label: Tr.tr("New column width")
            valueLabel: `${Math.round(root.sc("column_width", 0.5) * 100)}%`
            // 20% .. 100% of the screen
            value: (root.sc("column_width", 0.5) - 0.2) / 0.8
            onMoved: v => root.setSc("column_width", Math.round((0.2 + v * 0.8) * 100) / 100)
        }

        SelectRow {
            visible: root.scrollerLoaded
            label: Tr.tr("New windows")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Get their own column")
                    value: "column"
                },
                MenuItem {
                    text: Tr.tr("Stack in the current column")
                    value: "stack"
                }
            ]
            active: menuItems.find(i => i.value === root.sc("new_window_placement", "column")) ?? null
            onSelected: item => root.setSc("new_window_placement", item.value)
        }

        StepperRow {
            visible: root.scrollerLoaded && root.sc("new_window_placement", "column") === "column"
            label: Tr.tr("Stack after this many columns")
            subtext: Tr.tr("Once a workspace has this many, new windows stack; 0 for never")
            value: root.sc("stack_after_columns", 0)
            from: 0
            to: 8
            stepSize: 1
            onMoved: v => root.setSc("stack_after_columns", v)
        }

        SelectRow {
            visible: root.scrollerLoaded
            label: Tr.tr("Focused column")
            subtext: Tr.tr("Where the view puts the column you switch to")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Just into view")
                    value: 1
                },
                MenuItem {
                    text: Tr.tr("Centred")
                    value: 0
                },
                MenuItem {
                    text: Tr.tr("Centred, no gap at the edges")
                    value: 2
                }
            ]
            active: menuItems.find(i => i.value === root.sc("focus_fit_method", 0)) ?? null
            onSelected: item => root.setSc("focus_fit_method", item.value)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("Always centre the focused column")
            checked: root.sc("center_active_column", false)
            onToggled: root.setSc("center_active_column", checked ? 1 : 0)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("Scroll to the window under the pointer")
            subtext: Tr.tr("After resting on it for a moment")
            checked: root.sc("follow_hover", false)
            onToggled: root.setSc("follow_hover", checked ? 1 : 0)
        }

        StepperRow {
            visible: root.scrollerLoaded && root.sc("follow_hover", false)
            label: Tr.tr("Hover delay")
            subtext: Tr.tr("Milliseconds")
            value: root.sc("hover_delay_ms", 500)
            from: 100
            to: 2000
            stepSize: 50
            onMoved: v => root.setSc("hover_delay_ms", v)
        }

        StepperRow {
            visible: root.scrollerLoaded
            label: Tr.tr("Peek at neighbours")
            subtext: Tr.tr("Pixels of the columns beside the view that stay visible")
            value: root.sc("peek_width", 0)
            from: 0
            to: 200
            stepSize: 10
            onMoved: v => root.setSc("peek_width", v)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("Stretch columns to fill the screen")
            subtext: Tr.tr("When they don't fill it by themselves")
            checked: root.sc("stretch_to_fill", false)
            onToggled: root.setSc("stretch_to_fill", checked ? 1 : 0)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("A lone column fills the screen")
            checked: root.sc("fullscreen_on_one_column", false)
            onToggled: root.setSc("fullscreen_on_one_column", checked ? 1 : 0)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("Scroll within columns")
            subtext: Tr.tr("Windows in a column keep their own heights, and the column scrolls")
            checked: root.sc("column_scroll", false)
            onToggled: root.setSc("column_scroll", checked ? 1 : 0)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("Wrap around at the ends")
            subtext: Tr.tr("Moving focus past the last column goes to the first")
            checked: root.sc("focus_wrap", true)
            onToggled: root.setSc("focus_wrap", checked ? 1 : 0)
        }

        TextFieldRow {
            visible: root.scrollerLoaded
            label: Tr.tr("Column widths to cycle through")
            subtext: Tr.tr("Fractions of the screen, e.g. 0.333,0.5,0.667,1")
            value: root.sc("explicit_column_widths", "") || root.sc("column_widths", "0.333,0.5,0.667,1.0")
            validate: t => /^\s*(0?\.\d+|1(\.0+)?)(\s*,\s*(0?\.\d+|1(\.0+)?))*\s*$/.test(t)
            errorText: Tr.tr("Numbers from 0 to 1, separated by commas")
            onEditingFinished: v => {
                if (/^\s*(0?\.\d+|1(\.0+)?)(\s*,\s*(0?\.\d+|1(\.0+)?))*\s*$/.test(v))
                    root.setSc("explicit_column_widths", v.replace(/\s+/g, ""));
            }
        }

        SliderRow {
            visible: root.scrollerLoaded
            icon: "zoom_out_map"
            label: Tr.tr("Overview size")
            valueLabel: `${Math.round(root.sc("overview_zoom", 0.5) * 100)}%`
            // 20% .. 80%
            value: (root.sc("overview_zoom", 0.5) - 0.2) / 0.6
            onMoved: v => root.setSc("overview_zoom", Math.round((0.2 + v * 0.6) * 100) / 100)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            last: true
            text: Tr.tr("Window titles in the overview")
            checked: root.sc("overview_titles", true)
            onToggled: root.setSc("overview_titles", checked ? 1 : 0)
        }

        SectionHeader {
            text: Tr.tr("App rules")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("How an app's windows open: floating, centred, on a workspace, see-through, keeping the screen awake.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: ruleList

            model: root.rules

            RuleRow {}
        }

        SelectRow {
            first: root.rules.length === 0
            last: true
            label: Tr.tr("Add a rule for an open app")
            subtext: root.openClasses.length === 0 ? Tr.tr("Open the app first") : ""
            menuOnTop: true
            menuItems: classItems.instances
            active: null
            fallbackText: Tr.tr("Pick")
            fallbackIcon: "add"
            onSelected: item => {
                root.addRule(item.value);
                // The menu sets the picked one after this: back to "Pick" after it
                Qt.callLater(() => active = null);
            }

            Variants {
                id: classItems

                model: root.openClasses

                MenuItem {
                    required property string modelData

                    text: modelData
                    value: modelData
                }
            }
        }
    }

    component RuleRow: ConnectedRect {
        id: rule

        required property var modelData
        required property int index
        readonly property bool open: root.openRule === index
        // ^(org\.gnome\.Nautilus)$ -> org.gnome.Nautilus
        readonly property string app: modelData.class.replace(/^\^\(/, "").replace(/\)\$$/, "").replace(/\\(.)/g, "$1")

        Layout.fillWidth: true
        first: index === 0
        implicitHeight: ruleLayout.implicitHeight + Tokens.padding.medium * 2
        clip: true

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        StateLayer {
            anchors.fill: parent
            radius: rule.topLeftRadius
            disabled: rule.open
            onClicked: root.openRule = rule.index
        }

        ColumnLayout {
            id: ruleLayout

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
                        text: rule.app
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const m = rule.modelData;
                            const parts = [];
                            if (m.float)
                                parts.push(Tr.tr("floating"));
                            if (m.center)
                                parts.push(Tr.tr("centred"));
                            if (m.pin)
                                parts.push(Tr.tr("on every workspace"));
                            if (m.workspace)
                                parts.push(Tr.tr("workspace %1").arg(m.workspace));
                            if (m.opacity && m.opacity < 1)
                                parts.push(`${Math.round(m.opacity * 100)}%`);
                            if (m.idleInhibit)
                                parts.push(Tr.tr("keeps awake"));
                            if (m.immediate)
                                parts.push(Tr.tr("tearing allowed"));
                            return parts.join(", ") || Tr.tr("No changes");
                        }
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: rule.open ? "expand_less" : "delete"
                    type: IconButton.Text
                    onClicked: rule.open ? root.openRule = -1 : root.removeRule(rule.index)
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: rule.open
                columns: 2
                columnSpacing: Tokens.spacing.medium
                rowSpacing: Tokens.spacing.small

                RuleSwitch {
                    text: Tr.tr("Floating")
                    checked: !!rule.modelData.float
                    onToggled: root.setRule(rule.index, {
                        float: checked
                    })
                }

                RuleSwitch {
                    text: Tr.tr("Centred")
                    checked: !!rule.modelData.center
                    onToggled: root.setRule(rule.index, {
                        center: checked
                    })
                }

                RuleSwitch {
                    text: Tr.tr("On every workspace")
                    checked: !!rule.modelData.pin
                    onToggled: root.setRule(rule.index, {
                        pin: checked,
                        float: checked || rule.modelData.float
                    })
                }

                RuleSwitch {
                    text: Tr.tr("Keep the screen awake")
                    checked: !!rule.modelData.idleInhibit
                    onToggled: root.setRule(rule.index, {
                        idleInhibit: checked ? "focus" : ""
                    })
                }

                RuleSwitch {
                    text: Tr.tr("Allow tearing (games)")
                    checked: !!rule.modelData.immediate
                    onToggled: root.setRule(rule.index, {
                        immediate: checked
                    })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: rule.open
                spacing: Tokens.spacing.medium

                StyledText {
                    text: Tr.tr("Workspace")
                    font: Tokens.font.body.small
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    icon: "remove"
                    type: IconButton.Tonal
                    disabled: !(rule.modelData.workspace > 0)
                    onClicked: root.setRule(rule.index, {
                        workspace: Math.max(0, (rule.modelData.workspace ?? 0) - 1)
                    })
                }

                StyledText {
                    Layout.minimumWidth: 60
                    horizontalAlignment: Text.AlignHCenter
                    text: rule.modelData.workspace > 0 ? String(rule.modelData.workspace) : Tr.tr("Any")
                    font: Tokens.font.body.small
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Tonal
                    disabled: (rule.modelData.workspace ?? 0) >= 10
                    onClicked: root.setRule(rule.index, {
                        workspace: (rule.modelData.workspace ?? 0) + 1
                    })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: rule.open
                spacing: Tokens.spacing.medium

                StyledText {
                    text: Tr.tr("Opacity")
                    font: Tokens.font.body.small
                }

                StyledSlider {
                    Layout.fillWidth: true
                    from: 0.3
                    to: 1
                    value: rule.modelData.opacity ?? 1
                    onMoved: root.setRule(rule.index, {
                        opacity: Math.round(value * 100) / 100
                    })
                }

                StyledText {
                    Layout.minimumWidth: 40
                    text: `${Math.round((rule.modelData.opacity ?? 1) * 100)}%`
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: rule.open
                text: Tr.tr("Applies to windows opened from now on.")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    component RuleSwitch: RowLayout {
        property alias text: switchLabel.text
        property alias checked: sw.checked

        signal toggled

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
            id: switchLabel

            Layout.fillWidth: true
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }

        StyledSwitch {
            id: sw

            onToggled: parent.toggled()
        }
    }
}
