pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Title bars (hyprflow): enabled, hover reveal, size, alignment, font, blur,
// buttons, app icon and mouse click actions.
PageBase {
    id: root

    readonly property bool hyprflowLoaded: HyprSettings.values["plugin:hyprflow:bar_enabled"] !== undefined
    readonly property bool barOn: hyprflowLoaded && HyprSettings.value("plugin:hyprflow:bar_enabled", true)
    property string savedMenu: "fullscreen, maximize, float, pin, -, close"

    Component.onCompleted: {
        const cur = HyprSettings.value("plugin:hyprflow:bar_menu", "");
        if (cur)
            savedMenu = cur;
    }

    title: Tr.tr("Title bars")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            function onValuesChanged(): void {
                const cur = HyprSettings.value("plugin:hyprflow:bar_menu", "");
                if (cur)
                    root.savedMenu = cur;
            }

            target: HyprSettings
        }

        RequirementRow {
            visible: !root.hyprflowLoaded
            text: Tr.tr("Needs the hyprflow plugin")
            subtext: Tr.tr("Window title bars come from hyprflow, a Hyprland plugin. It isn't loaded right now.")
            actionText: Tr.tr("Plugins")
            onAction: root.nState.goTo({
                page: PageRegistry.find("plugins"),
                tab: "plugins",
                path: []
            })
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Title bars")
        }

        ToggleRow {
            visible: root.hyprflowLoaded
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

        SelectRow {
            visible: root.hyprflowLoaded && HyprSettings.value("plugin:hyprflow:bar_autohide", false)
            label: Tr.tr("Hover bar position")
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
            subtext: Tr.tr("Delay in ms before the bar appears (0 = instant)")
            value: HyprSettings.value("plugin:hyprflow:bar_autohide_delay_ms", 0)
            from: 0
            to: 1000
            stepSize: 50
            onMoved: v => HyprSettings.setHyprflow("bar_autohide_delay_ms", v)
        }

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Add title bars to apps that draw their own")
            subtext: Tr.tr("Browsers and GNOME apps get a system title bar above their own header bar")
            checked: HyprSettings.value("plugin:hyprflow:bar_csd", "bar") === "bar"
            onToggled: HyprSettings.setHyprflow("bar_csd", checked ? "bar" : "skip")
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Appearance")
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

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("Colour from the window")
            subtext: Tr.tr("The bar takes the colour of the app's top edge, so it blends in")
            checked: HyprSettings.value("plugin:hyprflow:bar_color_from_window", true)
            onToggled: HyprSettings.setHyprflow("bar_color_from_window", checked)
        }

        ToggleRow {
            visible: root.hyprflowLoaded && HyprSettings.value("decoration:blur:enabled", true) && HyprSettings.value("plugin:hyprflow:bar_blur", null) !== null
            text: Tr.tr("Blur title bars")
            subtext: Tr.tr("Frosted glass behind title bars, at windows' strength")
            checked: HyprSettings.value("plugin:hyprflow:bar_blur", true)
            onToggled: HyprSettings.setHyprflow("bar_blur", checked)
        }

        FontRow {
            visible: root.hyprflowLoaded && HyprSettings.values["plugin:hyprflow:bar_font"] !== undefined
            label: Tr.tr("Title font")
            family: HyprSettings.value("plugin:hyprflow:bar_font", "")
            onPicked: f => HyprSettings.setHyprflow("bar_font", f)
        }

        StepperRow {
            visible: root.hyprflowLoaded && HyprSettings.values["plugin:hyprflow:bar_font"] !== undefined
            label: Tr.tr("Title size")
            subtext: Tr.tr("In points")
            value: HyprSettings.value("plugin:hyprflow:bar_text_size", 10)
            from: 7
            to: 18
            stepSize: 1
            onMoved: v => HyprSettings.setHyprflow("bar_text_size", v)
        }

        SelectRow {
            visible: root.hyprflowLoaded && HyprSettings.values["plugin:hyprflow:bar_font"] !== undefined
            label: Tr.tr("Title weight")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Regular")
                    value: 400
                },
                MenuItem {
                    text: Tr.tr("Medium")
                    value: 500
                },
                MenuItem {
                    text: Tr.tr("Semi-bold")
                    value: 600
                },
                MenuItem {
                    text: Tr.tr("Bold")
                    value: 700
                }
            ]
            active: menuItems.find(i => i.value === HyprSettings.value("plugin:hyprflow:bar_text_weight", 600)) ?? null
            onSelected: item => HyprSettings.setHyprflow("bar_text_weight", item.value)
        }

        SectionHeader {
            visible: root.hyprflowLoaded
            text: Tr.tr("Buttons & icon")
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

        ToggleRow {
            visible: root.hyprflowLoaded
            text: Tr.tr("App icon")
            subtext: Tr.tr("Before the title")
            checked: HyprSettings.value("plugin:hyprflow:bar_icon", true)
            onToggled: HyprSettings.setHyprflow("bar_icon", checked)
        }

        StepperRow {
            visible: root.hyprflowLoaded && HyprSettings.value("plugin:hyprflow:bar_icon", true)
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
            text: Tr.tr("Mouse actions")
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
            onToggled: HyprSettings.setHyprflow("bar_menu", checked ? (root.savedMenu || "fullscreen, maximize, float, pin, -, close") : "")
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
}
