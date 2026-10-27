pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
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
            value: HyprSettings.value("plugin:hyprflow:bar_height", 26)
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
            checked: HyprSettings.value("plugin:hyprflow:bar_icon", false)
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
            last: true
            label: Tr.tr("Middle-click")
            option: "bar_middle_click"
            fallback: "close"
            menuOnTop: true
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
