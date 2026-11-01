pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Desktop mode (hyprflow): floating windows like Windows', title bars, hot
// corners. hyprflow.lua applies these over its own style.
PageBase {
    id: root

    readonly property bool hyprflowLoaded: HyprSettings.values["plugin:hyprflow:bar_enabled"] !== undefined

    // "top_left:overview, bottom_left:show_desktop" -> { top_left: "overview", ... }
    readonly property var corners: {
        const out = {};
        for (const part of String(HyprSettings.value("plugin:hyprflow:hot_corners", "")).split(",")) {
            const i = part.indexOf(":");
            if (i > 0)
                out[part.slice(0, i).trim()] = part.slice(i + 1).trim();
        }
        return out;
    }

    function setCorner(corner: string, action: string): void {
        const c = Object.assign({}, corners);
        if (action)
            c[corner] = action;
        else
            delete c[corner];
        HyprSettings.setHyprflow("hot_corners", Object.entries(c).map(([k, v]) => `${k}:${v}`).join(", "));
    }

    title: Tr.tr("Desktop mode")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Desktop mode")
        }

        ToggleRow {
            first: true
            last: true
            disabled: !root.hyprflowLoaded
            text: Tr.tr("Desktop mode")
            subtext: root.hyprflowLoaded ? Tr.tr("Windows float and overlap, with title bars, snapping and a taskbar, like Windows") : Tr.tr("Needs the hyprflow Hyprland plugin")
            checked: Hypr.desktopMode
            onToggled: Hypr.toggleDesktopMode()
        }

        RequirementRow {
            Layout.topMargin: Tokens.spacing.small
            visible: !root.hyprflowLoaded
            first: true
            last: true
            text: Tr.tr("Needs the hyprflow plugin")
            subtext: Tr.tr("Desktop mode, title bars, snapping, minimizing and hot corners come from hyprflow, a Hyprland plugin. It isn't loaded right now.")
            actionText: Tr.tr("Plugins")
            onAction: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "plugins"),
                path: []
            })
        }

        // Snapping (Windows 11): edges/corners, the layouts flyout, Snap Assist, groups
        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Snapping")
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            first: true
            text: Tr.tr("Snap windows")
            subtext: Tr.tr("Drag a window to a screen edge or corner to fill half or a quarter of it, or to the top to maximize")
            checked: HyprSettings.value("plugin:hyprflow:snap_enabled", true)
            onToggled: HyprSettings.setHyprflow("snap_enabled", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Snap layouts")
            subtext: Tr.tr("Rest the pointer on a window's maximize button to pick a layout for it")
            checked: HyprSettings.value("plugin:hyprflow:snap_layouts", true)
            onToggled: HyprSettings.setHyprflow("snap_layouts", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Suggest what to snap next")
            subtext: Tr.tr("After snapping a window, pick another one to fill the rest of the screen")
            checked: HyprSettings.value("plugin:hyprflow:snap_assist", true)
            onToggled: HyprSettings.setHyprflow("snap_assist", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            last: true
            text: Tr.tr("Resize snapped windows together")
            subtext: Tr.tr("Dragging the edge between two snapped windows resizes both")
            checked: HyprSettings.value("plugin:hyprflow:snap_groups", true)
            onToggled: HyprSettings.setHyprflow("snap_groups", checked)
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Windows")
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            first: true
            text: Tr.tr("Minimize animation")
            subtext: Tr.tr("Windows pour into their taskbar icon (genie); off: at once")
            checked: HyprSettings.value("plugin:hyprflow:minimize_animation", true)
            onToggled: HyprSettings.setHyprflow("minimize_animation", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            last: true
            text: Tr.tr("Keep windows drawing out of view")
            subtext: Tr.tr("Videos and games keep running behind other windows; off saves power")
            checked: HyprSettings.value("plugin:hyprflow:keep_alive", true)
            onToggled: HyprSettings.setHyprflow("keep_alive", checked)
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Title bars")
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            first: true
            text: Tr.tr("Title bars")
            subtext: Tr.tr("A bar on top of each window with its title and buttons")
            checked: HyprSettings.value("plugin:hyprflow:bar_enabled", true)
            onToggled: HyprSettings.setHyprflow("bar_enabled", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Show only on hover")
            subtext: Tr.tr("The bar appears when the pointer reaches the top of a window, and takes no space")
            checked: HyprSettings.value("plugin:hyprflow:bar_autohide", false)
            onToggled: HyprSettings.setHyprflow("bar_autohide", checked)
        }

        StepperRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Height")
            subtext: Tr.tr("In pixels")
            value: HyprSettings.value("plugin:hyprflow:bar_height", 28)
            from: 18
            to: 48
            stepSize: 1
            onMoved: v => HyprSettings.setHyprflow("bar_height", v)
        }

        SelectRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Title")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Left")
                    value: "left"
                },
                MenuItem {
                    text: Tr.tr("Centred")
                    value: "center"
                },
                MenuItem {
                    text: Tr.tr("Right")
                    value: "right"
                }
            ]
            active: menuItems.find(i => i.value === HyprSettings.value("plugin:hyprflow:bar_text_align", "center")) ?? null
            onSelected: item => HyprSettings.setHyprflow("bar_text_align", item.value)
        }

        SelectRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Buttons")
            menuItems: [
                MenuItem {
                    text: Tr.tr("On the right, like Windows")
                    value: "right"
                },
                MenuItem {
                    text: Tr.tr("On the left, like macOS")
                    value: "left"
                }
            ]
            active: menuItems.find(i => i.value === HyprSettings.value("plugin:hyprflow:bar_buttons_align", "right")) ?? null
            onSelected: item => HyprSettings.setHyprflow("bar_buttons_align", item.value)
        }

        SelectRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Which buttons")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Minimize, maximize, close")
                    value: "minimize:−:0xfffebc2e, maximize:+:0xff28c840, close:×:0xffff5f57"
                },
                MenuItem {
                    text: Tr.tr("Minimize, fullscreen, close")
                    value: "minimize:−:0xfffebc2e, fullscreen:□:0xff28c840, close:×:0xffff5f57"
                },
                MenuItem {
                    text: Tr.tr("Maximize, close")
                    value: "maximize:+:0xff28c840, close:×:0xffff5f57"
                },
                MenuItem {
                    text: Tr.tr("Close only")
                    value: "close:×:0xffff5f57"
                }
            ]
            active: {
                const norm = v => String(v).replace(/\s+/g, "");
                const cur = norm(HyprSettings.value("plugin:hyprflow:bar_buttons", ""));
                return menuItems.find(i => norm(i.value) === cur) ?? null;
            }
            fallbackText: Tr.tr("Custom")
            onSelected: item => HyprSettings.setHyprflow("bar_buttons", item.value)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Button symbols only on hover")
            checked: HyprSettings.value("plugin:hyprflow:bar_button_icons_on_hover", false)
            onToggled: HyprSettings.setHyprflow("bar_button_icons_on_hover", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("App icon")
            subtext: Tr.tr("Before the title")
            checked: HyprSettings.value("plugin:hyprflow:bar_icon", true)
            onToggled: HyprSettings.setHyprflow("bar_icon", checked)
        }

        ClickRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Double-click")
            option: "bar_double_click"
            fallback: "maximize"
        }

        ClickRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Middle-click")
            option: "bar_middle_click"
            fallback: "close"
            menuOnTop: true
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Right-click menu")
            subtext: Tr.tr("Maximize, float, pin, close and more, from the title bar")
            checked: HyprSettings.value("plugin:hyprflow:bar_menu", "x") !== ""
            onToggled: HyprSettings.setHyprflow("bar_menu", checked ? "fullscreen, maximize, float, pin, -, close" : "")
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Colour from the window")
            subtext: Tr.tr("The bar takes the colour of the app's top edge, so it blends in")
            checked: HyprSettings.value("plugin:hyprflow:bar_color_from_window", true)
            onToggled: HyprSettings.setHyprflow("bar_color_from_window", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Frosted bars")
            subtext: Tr.tr("Blur behind see-through title bars")
            checked: HyprSettings.value("plugin:hyprflow:bar_blur", true)
            onToggled: HyprSettings.setHyprflow("bar_blur", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Bars on apps with their own")
            subtext: Tr.tr("Apps that draw their own title bar (GNOME apps, browsers) get one too")
            checked: HyprSettings.value("plugin:hyprflow:bar_csd", "bar") === "bar"
            onToggled: HyprSettings.setHyprflow("bar_csd", checked ? "bar" : "skip")
        }

        SelectRow {
            visible: root.hyprflowLoaded && HyprSettings.value("plugin:hyprflow:bar_autohide", false)
            label: Tr.tr("Hover bar position")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Above the window, in the gap")
                    value: "above"
                },
                MenuItem {
                    text: Tr.tr("Over the window's top")
                    value: "over"
                }
            ]
            active: menuItems.find(i => i.value === HyprSettings.value("plugin:hyprflow:bar_autohide_position", "above")) ?? null
            onSelected: item => HyprSettings.setHyprflow("bar_autohide_position", item.value)
        }

        StepperRow {
            visible: root.hyprflowLoaded && HyprSettings.value("plugin:hyprflow:bar_autohide", false)
            label: Tr.tr("Hover delay")
            subtext: Tr.tr("Milliseconds before the bar shows")
            value: HyprSettings.value("plugin:hyprflow:bar_autohide_delay_ms", 0)
            from: 0
            to: 1000
            stepSize: 50
            onMoved: v => HyprSettings.setHyprflow("bar_autohide_delay_ms", v)
        }

        StepperRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Button size")
            subtext: Tr.tr("In pixels")
            value: HyprSettings.value("plugin:hyprflow:bar_button_size", 12)
            from: 8
            to: 24
            stepSize: 1
            onMoved: v => HyprSettings.setHyprflow("bar_button_size", v)
        }

        StepperRow {
            visible: root.hyprflowLoaded
            last: true
            label: Tr.tr("App icon size")
            subtext: Tr.tr("In pixels")
            value: HyprSettings.value("plugin:hyprflow:bar_icon_size", 14)
            from: 10
            to: 28
            stepSize: 1
            onMoved: v => HyprSettings.setHyprflow("bar_icon_size", v)
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Hot corners")
        }

        CornerRow {
            visible: root.hyprflowLoaded
            first: true
            label: Tr.tr("Top left")
            corner: "top_left"
        }

        CornerRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Top right")
            corner: "top_right"
        }

        CornerRow {
            visible: root.hyprflowLoaded
            label: Tr.tr("Bottom left")
            corner: "bottom_left"
            menuOnTop: true
        }

        CornerRow {
            visible: root.hyprflowLoaded
            last: true
            label: Tr.tr("Bottom right")
            corner: "bottom_right"
            menuOnTop: true
        }
    }

    // What clicking a title bar does
    component ClickRow: SelectRow {
        required property string option
        required property string fallback

        menuItems: [
            MenuItem {
                text: Tr.tr("Maximize or restore")
                value: "maximize"
            },
            MenuItem {
                text: Tr.tr("Fullscreen")
                value: "fullscreen"
            },
            MenuItem {
                text: Tr.tr("Minimize")
                value: "minimize"
            },
            MenuItem {
                text: Tr.tr("Close")
                value: "close"
            },
            MenuItem {
                text: Tr.tr("Nothing")
                value: ""
            }
        ]
        active: menuItems.find(i => i.value === HyprSettings.value(`plugin:hyprflow:${option}`, fallback)) ?? null
        onSelected: item => HyprSettings.setHyprflow(option, item.value)
    }

    // What resting the pointer in a screen corner does
    component CornerRow: SelectRow {
        required property string corner

        subtext: ""
        menuItems: [
            MenuItem {
                text: Tr.tr("Nothing")
                value: ""
            },
            MenuItem {
                text: Tr.tr("All windows")
                value: "overview"
            },
            MenuItem {
                text: Tr.tr("Show the desktop")
                value: "show_desktop"
            },
            MenuItem {
                text: Tr.tr("App launcher")
                value: "launcher"
            },
            MenuItem {
                text: Tr.tr("Desktop mode on/off")
                value: "desktop_mode"
            }
        ]
        active: menuItems.find(i => i.value === (root.corners[corner] ?? "")) ?? null
        onSelected: item => root.setCorner(corner, item.value)
    }
}
