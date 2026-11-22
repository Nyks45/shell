pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Focus and workspaces (Hyprland options; focus is set apart for desktop mode
// and the scrolling layout).
PageBase {
    id: root

    readonly property bool hyprflowLoaded: HyprSettings.values["plugin:hyprflow:bar_enabled"] !== undefined

    // The scrolling layout (hyprscroller)
    readonly property bool scrollerLoaded: HyprSettings.values["plugin:hyprscrolling:column_width"] !== undefined

    function sc(name: string, fallback: var): var {
        return HyprSettings.value(`plugin:hyprscrolling:${name}`, fallback);
    }

    function setSc(name: string, val: var): void {
        HyprSettings.setOption(`plugin:hyprscrolling:${name}`, val);
    }

    title: Tr.tr("Workspaces & focus")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Focus")
        }

        ToggleRow {
            text: Tr.tr("Focus follows the mouse (scrolling layout)")
            subtext: Tr.tr("In the scrolling layout, the window under the pointer gets keyboard focus")
            checked: HyprSettings.modeValue("tiling", "input:follow_mouse", 1) === 1
            onToggled: HyprSettings.setModeOption("tiling", "input:follow_mouse", checked ? 1 : 0)
        }

        ToggleRow {
            text: Tr.tr("Focus follows the mouse (desktop mode)")
            disabled: !root.hyprflowLoaded
            subtext: root.hyprflowLoaded ? Tr.tr("In floating desktop mode; off means click to focus, like Windows") : Tr.tr("Needs the hyprflow plugin (desktop mode)")
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
            text: Tr.tr("Move the pointer with the focus")
            subtext: Tr.tr("When the keyboard switches windows, the pointer jumps to the new one")
            checked: !HyprSettings.value("cursor:no_warps", false)
            onToggled: HyprSettings.setOption("cursor:no_warps", !checked)
        }

        SectionHeader {
            text: Tr.tr("Workspaces")
        }

        ToggleRow {
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

        // Alt+Tab switcher and Overview behaviour (hyprflow + hyprscrolling)
        SectionHeader {
            text: Tr.tr("Window switcher & overview")
        }

        SelectRow {
            label: Tr.tr("Alt + Tab style")
            subtext: Tr.tr("Overview switcher shows thumbnails of all windows; Quick cycle steps directly")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Overview switcher")
                    value: "overview"
                },
                MenuItem {
                    text: Tr.tr("Quick cycle")
                    value: "cycle"
                }
            ]
            active: menuItems.find(i => i.value === (HyprSettings.saved.altTab?.style ?? "overview")) ?? menuItems[0]
            onSelected: item => HyprSettings.setAltTab({
                    style: item.value
                })
        }

        SelectRow {
            visible: (HyprSettings.saved.altTab?.style ?? "overview") === "cycle"
            label: Tr.tr("Windows in Quick cycle")
            subtext: Tr.tr("Which windows Alt + Tab cycles through on the current workspace")
            menuItems: [
                MenuItem {
                    text: Tr.tr("All windows")
                    value: "all"
                },
                MenuItem {
                    text: Tr.tr("Tiled windows only")
                    value: "tiled"
                },
                MenuItem {
                    text: Tr.tr("Floating windows only")
                    value: "floating"
                }
            ]
            active: menuItems.find(i => i.value === (HyprSettings.saved.altTab?.scope ?? "all")) ?? menuItems[0]
            onSelected: item => HyprSettings.setAltTab({
                    scope: item.value
                })
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
            text: Tr.tr("Window titles in the overview")
            checked: root.sc("overview_titles", true)
            onToggled: root.setSc("overview_titles", checked ? 1 : 0)
        }

        ToggleRow {
            visible: root.scrollerLoaded
            text: Tr.tr("Animate overview transitions")
            subtext: Tr.tr("Smooth zoom into and out of the overview (off: instant)")
            checked: !!root.sc("overview_animate", true)
            onToggled: root.setSc("overview_animate", checked ? 1 : 0)
        }

        // The scrolling layout: columns of windows side by side, scrolled through
        SectionHeader {
            text: Tr.tr("Scrolling layout")
        }

        RequirementRow {
            visible: !root.scrollerLoaded
            text: Tr.tr("Needs the hyprscroller plugin")
            subtext: Tr.tr("The scrolling layout (columns side by side) comes from hyprscroller, which isn't loaded.")
            actionText: Tr.tr("Plugins")
            onAction: root.nState.goTo({
                page: PageRegistry.find("plugins"),
                tab: "plugins",
                path: []
            })
        }

        SliderRow {
            visible: root.scrollerLoaded
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
            subtext: Tr.tr("How long the pointer rests before scrolling (in milliseconds)")
            value: root.sc("hover_delay_ms", 500)
            from: 100
            to: 2000
            stepSize: 50
            onMoved: v => root.setSc("hover_delay_ms", v)
        }

        StepperRow {
            visible: root.scrollerLoaded
            label: Tr.tr("Peek at neighbours")
            subtext: Tr.tr("How much of the next column stays visible at the screen edge (0 = none)")
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

        ConnectedRect {
            id: widthPresetsRow

            readonly property var presets: [
                {
                    pct: 25,
                    val: "0.25"
                },
                {
                    pct: 33,
                    val: "0.333"
                },
                {
                    pct: 50,
                    val: "0.5"
                },
                {
                    pct: 67,
                    val: "0.667"
                },
                {
                    pct: 75,
                    val: "0.75"
                },
                {
                    pct: 100,
                    val: "1.0"
                }
            ]
            readonly property var activeNums: String(root.sc("explicit_column_widths", "") || root.sc("column_widths", "0.333,0.5,0.667,1.0")).split(",").map(s => parseFloat(s.trim())).filter(n => !isNaN(n) && n > 0 && n <= 1.01)

            function isSelected(pct: int): bool {
                return activeNums.some(n => Math.abs(n * 100 - pct) <= 1.5);
            }

            function togglePreset(pct: int): void {
                const chosen = presets.filter(p => p.pct === pct ? !isSelected(p.pct) : isSelected(p.pct));
                if (chosen.length === 0)
                    return;
                root.setSc("explicit_column_widths", chosen.map(p => p.val).join(","));
            }

            visible: root.scrollerLoaded
            Layout.fillWidth: true
            implicitHeight: widthCol.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: widthCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Column widths to cycle through")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Widths available when cycling column size")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: widthPresetsRow.presets

                        TextButton {
                            required property var modelData

                            text: `${modelData.pct}%`
                            isToggle: true
                            followChecked: true
                            checked: widthPresetsRow.isSelected(modelData.pct)
                            type: TextButton.Tonal
                            onClicked: widthPresetsRow.togglePreset(modelData.pct)
                        }
                    }
                }
            }
        }
    }
}
