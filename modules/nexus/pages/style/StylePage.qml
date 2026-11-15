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

// Wallpaper & style > Nebula: the parts of the Nebula look (github.com/LilaccFlowerr/Nebula, see
// NEBULA.md), each one an option next to the shell's own. Blur is not here: all of it is in
// Wallpaper & style > Blur.
PageBase {
    id: root

    title: Tr.tr("Nebula")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Desktop widgets")
        }

        ToggleRow {
            text: Tr.tr("Desktop widgets")
            subtext: Tr.tr("Clock, calendar, weather, battery, now playing, lyrics, pictures, notes and system info in Material shapes on the desktop")
            checked: GlobalConfig.appearance.style.desktopWidgets
            onToggled: GlobalConfig.appearance.style.desktopWidgets = checked
        }

        RowButton {
            Layout.fillWidth: true
            visible: GlobalConfig.appearance.style.desktopWidgets
            icon: "widgets"
            text: Tr.tr("Widgets and layouts")
            subtext: Tr.tr("Add, change and arrange them. On the desktop: right-click for the menu; Super+Shift+E to edit")
            onClicked: root.nState.openSubPage(10)
        }

        SectionHeader {
            text: Tr.tr("Launcher")
        }

        SelectRow {
            label: Tr.tr("Launcher")
            subtext: GlobalConfig.appearance.style.launcher === "nebula" ? Tr.tr("A ring of apps around a search pill. Type > for commands; Theme, Variant, Wallpaper and Calculator open pickers in the ring") : Tr.tr("The list that slides up from the bottom edge")
            menuItems: [caelestiaLauncher, nebulaLauncher]
            active: GlobalConfig.appearance.style.launcher === "nebula" ? nebulaLauncher : caelestiaLauncher
            onSelected: item => GlobalConfig.appearance.style.launcher = item.value

            MenuItem {
                id: caelestiaLauncher

                icon: "view_list"
                text: Tr.tr("Caelestia list")
                value: "caelestia"
            }

            MenuItem {
                id: nebulaLauncher

                icon: "filter_vintage"
                text: Tr.tr("Nebula ring")
                value: "nebula"
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.normal
            Layout.bottomMargin: Tokens.spacing.small
            // TRANSLATORS: where the launcher's contents come from, whatever its style
            text: Tr.tr("Either style opens the same way (Super, the hot corner, the bar's logo) and uses the same apps, hidden apps and actions from Settings > Launcher.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            text: Tr.tr("Animations")
        }

        SelectRow {
            id: shellAnimRow

            readonly property var descriptions: ({
                    caelestia: Tr.tr("Panels, popouts, settings and the launcher: Caelestia's own motion"),
                    nebula: Tr.tr("Panels grow out of their edge like Nebula's media island, content settling in"),
                    island: Tr.tr("Like Nebula, on a spring: grows out of its edge, keeps its momentum"),
                    spring: Tr.tr("A physics spring: slides in and settles without bouncing, reverses smoothly mid-way"),
                    m3spring: Tr.tr("Material 3 Expressive's springs, settling without a bounce"),
                    glide: Tr.tr("A long, soft glide: quick start, gentle landing")
                })

            label: Tr.tr("Panels and popouts")
            subtext: descriptions[GlobalConfig.appearance.style.shellAnim] ?? descriptions.caelestia
            menuItems: shellAnimItems.instances
            active: shellAnimItems.instances.find(i => i.value === GlobalConfig.appearance.style.shellAnim) ?? shellAnimItems.instances[0] ?? null
            onSelected: item => GlobalConfig.appearance.style.shellAnim = item.value

            Variants {
                id: shellAnimItems

                model: [
                    {
                        value: "caelestia",
                        icon: "animation",
                        text: Tr.tr("Caelestia")
                    },
                    {
                        value: "nebula",
                        icon: "filter_vintage",
                        text: Tr.tr("Nebula expand")
                    },
                    {
                        value: "island",
                        icon: "pill",
                        text: Tr.tr("Island morph")
                    },
                    {
                        value: "spring",
                        icon: "airwave",
                        text: Tr.tr("Spring")
                    },
                    {
                        value: "m3spring",
                        icon: "motion_mode",
                        text: Tr.tr("M3 springs")
                    },
                    {
                        value: "glide",
                        icon: "air",
                        text: Tr.tr("Fluid glide")
                    }
                ]

                MenuItem {
                    required property var modelData

                    icon: modelData.icon
                    text: modelData.text
                    value: modelData.value
                }
            }
        }

        AnimRow {
            label: Tr.tr("Windows")
            what: Tr.tr("opening, closing, moving and resizing")
            style: HyprSettings.animStyle("windows")
            onPicked: v => HyprSettings.setAnimStyle("windows", v)
        }

        AnimRow {
            label: Tr.tr("Workspaces")
            what: Tr.tr("switching workspaces and the special workspace")
            style: HyprSettings.animStyle("workspaces")
            onPicked: v => HyprSettings.setAnimStyle("workspaces", v)
        }

        AnimRow {
            label: Tr.tr("Other shell surfaces")
            what: Tr.tr("notifications, menus and overlays")
            style: HyprSettings.animStyle("layers")
            onPicked: v => HyprSettings.setAnimStyle("layers", v)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.normal
            Layout.bottomMargin: Tokens.spacing.small
            // TRANSLATORS: where the one speed setting for all animations is
            text: Tr.tr("Nebula's widgets and launcher always move their own way. How fast everything moves (or no animations): Accessibility.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            text: Tr.tr("Glass")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.normal
            Layout.bottomMargin: Tokens.spacing.small
            // TRANSLATORS: explains what the glass sliders change (not the blur)
            text: Tr.tr("How Nebula's glass shapes look: the desktop widgets now, the islands and cards later. The blur behind them is under Wallpaper & style > Blur.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SliderRow {
            icon: "blur_on"
            label: Tr.tr("Glass tint")
            valueLabel: `${Math.round(GlobalConfig.appearance.glass.tint * 100)}%`
            // 30% (clear) .. 100% (solid)
            value: (GlobalConfig.appearance.glass.tint - 0.3) / 0.7
            onMoved: v => GlobalConfig.appearance.glass.tint = Math.round((0.3 + v * 0.7) * 100) / 100
        }

        SliderRow {
            icon: "wb_twilight"
            label: Tr.tr("Light across the top")
            valueLabel: `${Math.round(GlobalConfig.appearance.glass.topLight * 100)}%`
            // 0 .. 30%
            value: GlobalConfig.appearance.glass.topLight / 0.3
            onMoved: v => GlobalConfig.appearance.glass.topLight = Math.round(v * 30) / 100
        }
    }

    // One area's animation style: the same six choices as the shell's panels
    component AnimRow: SelectRow {
        id: animRow

        required property string what
        required property string style
        readonly property var styleNames: ({
                caelestia: Tr.tr("Caelestia's own"),
                nebula: Tr.tr("Nebula's decelerating curve"),
                island: Tr.tr("an island spring, growing from the centre"),
                spring: Tr.tr("a physics spring, no bounce"),
                m3spring: Tr.tr("Material 3 Expressive springs, no bounce"),
                glide: Tr.tr("a long, soft glide")
            })

        signal picked(string value)

        subtext: `${what}: ${styleNames[style] ?? styleNames.caelestia}`
        menuItems: animItems.instances
        active: animItems.instances.find(i => i.value === style) ?? animItems.instances[0] ?? null
        onSelected: item => picked(item.value)

        Variants {
            id: animItems

            model: [
                {
                    value: "caelestia",
                    icon: "animation",
                    text: Tr.tr("Caelestia")
                },
                {
                    value: "nebula",
                    icon: "filter_vintage",
                    text: Tr.tr("Nebula")
                },
                {
                    value: "island",
                    icon: "pill",
                    text: Tr.tr("Island morph")
                },
                {
                    value: "spring",
                    icon: "airwave",
                    text: Tr.tr("Spring")
                },
                {
                    value: "m3spring",
                    icon: "motion_mode",
                    text: Tr.tr("M3 springs")
                },
                {
                    value: "glide",
                    icon: "air",
                    text: Tr.tr("Fluid glide")
                }
            ]

            MenuItem {
                required property var modelData

                icon: modelData.icon
                text: modelData.text
                value: modelData.value
            }
        }
    }
}
