pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Accessibility: text size, motion, zoom, colour filters (Hyprland screen
// shaders in assets/shaders), contrast; links to the cursor and key repeat.
PageBase {
    id: root

    readonly property string shaderDir: `${Quickshell.shellDir}/assets/shaders`
    readonly property string shader: HyprSettings.value("decoration:screen_shader", "")
    readonly property string filter: shader.endsWith("/greyscale.frag") ? "greyscale" : shader.endsWith("/invert.frag") ? "invert" : shader.endsWith("/deuteranopia.frag") ? "deuteranopia" : shader ? "custom" : ""
    readonly property bool animationsOn: HyprSettings.value("animations:enabled", true) && GlobalConfig.appearance.anim.durations.scale > 0.05

    function setAnimations(on: bool): void {
        HyprSettings.setOption("animations:enabled", on);
        GlobalConfig.appearance.anim.durations.scale = on ? 1 : 0.01;
        AppLook.set("org.gnome.desktop.interface", "enable-animations", on);
    }

    title: Tr.tr("Accessibility")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Text")
        }

        SliderRow {
            first: true
            icon: "format_size"
            label: Tr.tr("Text size in apps")
            valueLabel: `${Math.round(AppLook.get("org.gnome.desktop.interface", "text-scaling-factor", 1) * 100)}%`
            // 100% .. 200%
            value: AppLook.get("org.gnome.desktop.interface", "text-scaling-factor", 1) - 1
            onMoved: v => AppLook.set("org.gnome.desktop.interface", "text-scaling-factor", Math.round((1 + v) * 20) / 20)
        }

        SliderRow {
            icon: "text_increase"
            label: Tr.tr("Text size in the shell")
            valueLabel: `${Math.round(Config.appearance.font.scale * 100)}%`
            value: (Config.appearance.font.scale - 0.8) / 0.7
            onMoved: v => GlobalConfig.appearance.font.scale = Math.round((0.8 + v * 0.7) * 20) / 20
        }

        ToggleRow {
            last: true
            text: Tr.tr("High contrast in apps")
            subtext: Tr.tr("GTK apps draw with stronger borders and colours")
            checked: AppLook.get("org.gnome.desktop.a11y.interface", "high-contrast", false)
            onToggled: AppLook.set("org.gnome.desktop.a11y.interface", "high-contrast", checked)
        }

        SectionHeader {
            text: Tr.tr("Seeing the screen")
        }

        SliderRow {
            first: true
            icon: "zoom_in"
            label: Tr.tr("Zoom")
            valueLabel: `${Math.round(HyprSettings.value("cursor:zoom_factor", 1) * 100)}%`
            // 100% .. 400%, around the pointer
            value: (HyprSettings.value("cursor:zoom_factor", 1) - 1) / 3
            onMoved: v => HyprSettings.setOption("cursor:zoom_factor", Math.round((1 + v * 3) * 10) / 10)
        }

        SelectRow {
            label: Tr.tr("Colour filter")
            subtext: root.filter === "custom" ? root.shader : Tr.tr("Changes the colours of the whole screen")
            menuItems: [
                MenuItem {
                    text: Tr.tr("None")
                    value: ""
                },
                MenuItem {
                    text: Tr.tr("Greyscale")
                    value: "greyscale"
                },
                MenuItem {
                    text: Tr.tr("Inverted colours")
                    value: "invert"
                },
                MenuItem {
                    text: Tr.tr("Red-green correction")
                    value: "deuteranopia"
                }
            ]
            active: menuItems.find(i => i.value === root.filter) ?? null
            fallbackText: Tr.tr("Custom")
            onSelected: item => HyprSettings.setOption("decoration:screen_shader", item.value ? `${root.shaderDir}/${item.value}.frag` : "")
        }

        NavRow {
            last: true
            icon: "arrow_selector_tool"
            text: Tr.tr("Bigger cursor")
            subtext: Tr.tr("Cursor size, on Keyboard & mouse")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "input"),
                path: [],
                text: Tr.tr("Cursor size"),
                sectionText: Tr.tr("Cursor")
            })
        }

        SectionHeader {
            text: Tr.tr("Motion")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Animations")
            subtext: Tr.tr("Off: windows, panels and apps change at once, without movement")
            checked: root.animationsOn
            onToggled: root.setAnimations(checked)
        }

        SliderRow {
            last: true
            visible: root.animationsOn
            icon: "speed"
            label: Tr.tr("Shell animation speed")
            // 0.5x (slower) .. 2x (faster): the duration scale is its inverse
            valueLabel: `${(1 / GlobalConfig.appearance.anim.durations.scale).toFixed(1)}×`
            value: (1 / GlobalConfig.appearance.anim.durations.scale - 0.5) / 1.5
            onMoved: v => GlobalConfig.appearance.anim.durations.scale = Math.round(100 / (0.5 + v * 1.5)) / 100
        }

        SectionHeader {
            text: Tr.tr("Keyboard")
        }

        NavRow {
            first: true
            last: true
            icon: "keyboard"
            text: Tr.tr("Key repeat")
            subtext: Tr.tr("How soon and how fast a held key repeats")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "input"),
                path: [],
                text: Tr.tr("Repeat delay"),
                sectionText: Tr.tr("Keyboard")
            })
        }
    }
}
