pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Desktop mode (hyprflow): floating windows like Windows', snapping, minimize
// and hot corners. hyprflow.lua applies these over its own style.
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
            text: Tr.tr("Desktop mode")
        }

        ToggleRow {
            disabled: !root.hyprflowLoaded
            text: Tr.tr("Desktop mode")
            subtext: root.hyprflowLoaded ? Tr.tr("Windows float and overlap, with title bars, snapping and a taskbar, like Windows") : Tr.tr("Needs the hyprflow Hyprland plugin")
            checked: Hypr.desktopMode
            onToggled: Hypr.toggleDesktopMode()
        }

        RequirementRow {
            visible: !root.hyprflowLoaded
            text: Tr.tr("Needs the hyprflow plugin")
            subtext: Tr.tr("Desktop mode, title bars, snapping, minimizing and hot corners come from hyprflow, a Hyprland plugin. It isn't loaded right now.")
            actionText: Tr.tr("Plugins")
            onAction: root.nState.goTo({
                page: PageRegistry.find("plugins"),
                tab: "plugins",
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
            text: Tr.tr("Minimize animation")
            subtext: Tr.tr("Windows pour into their taskbar icon (genie); off: at once")
            checked: HyprSettings.value("plugin:hyprflow:minimize_animation", true)
            onToggled: HyprSettings.setHyprflow("minimize_animation", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Keep windows drawing out of view")
            subtext: Tr.tr("Videos and games keep running behind other windows; off saves power")
            checked: HyprSettings.value("plugin:hyprflow:keep_alive", true)
            onToggled: HyprSettings.setHyprflow("keep_alive", checked)
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Hot corners")
        }

        CornerRow {
            visible: root.hyprflowLoaded
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
            label: Tr.tr("Bottom right")
            corner: "bottom_right"
            menuOnTop: true
        }
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
