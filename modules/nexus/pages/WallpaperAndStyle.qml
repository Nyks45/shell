pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Wallpaper & style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        ClipRect {
            id: wallWrapper

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: {
                const screen = root.nState.screen;
                return implicitHeight / screen.height * screen.width;
            }
            implicitHeight: {
                const screen = root.nState.screen;
                const cWidth = root.cappedWidth;
                return Math.min(Math.round(cWidth * 0.4), cWidth / screen.width * screen.height);
            }

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            Loader {
                anchors.centerIn: parent
                opacity: Config.background.wallpaperEnabled ? 0 : 1
                active: opacity > 0

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Wallpaper disabled")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.large
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            WallpaperImpl {
                anchors.fill: parent
                opacity: Config.background.wallpaperEnabled ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }
        }

        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "wallpaper"
                text: Tr.tr("Wallpapers")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                disabled: !Config.background.wallpaperEnabled
                onClicked: root.nState.openSubPage(1) // Wallpaper page
            }

            IconTextButton {
                icon: "palette"
                text: Tr.tr("Colours")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(3) // Colours page
            }
        }

        ToggleRow {
            first: true
            text: Tr.tr("Display wallpaper")
            checked: Config.background.wallpaperEnabled
            onToggled: GlobalConfig.background.wallpaperEnabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            text: Tr.tr("Desktop icons")
            subtext: Tr.tr("Show what's in the Desktop folder on the desktop")
            checked: Config.background.desktopIcons
            onToggled: GlobalConfig.background.desktopIcons = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            text: Tr.tr("Transparency")
            // TRANSLATORS: %1/%2 = opacity values from 0 to 1 for the base surface and layered surfaces
            subtext: Tr.tr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            text: Tr.tr("Dark theme")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        SliderRow {
            visible: Colours.transparency.enabled
            icon: "opacity"
            label: Tr.tr("Panel opacity")
            valueLabel: `${Math.round(GlobalConfig.appearance.transparency.base * 100)}%`
            value: GlobalConfig.appearance.transparency.base
            onMoved: v => GlobalConfig.appearance.transparency.base = Math.round(v * 100) / 100
        }

        SliderRow {
            visible: Colours.transparency.enabled
            icon: "layers"
            label: Tr.tr("Opacity of layers on panels")
            valueLabel: `${Math.round(GlobalConfig.appearance.transparency.layers * 100)}%`
            value: GlobalConfig.appearance.transparency.layers
            onMoved: v => GlobalConfig.appearance.transparency.layers = Math.round(v * 100) / 100
        }

        SliderRow {
            last: true
            icon: "rounded_corner"
            label: Tr.tr("Roundness of the shell")
            valueLabel: `${Math.round(Config.appearance.rounding.scale * 100)}%`
            // 0% (square) .. 200%
            value: Config.appearance.rounding.scale / 2
            onMoved: v => GlobalConfig.appearance.rounding.scale = Math.round(v * 40) / 20
        }

        // Wallpaper
        SectionHeader {
            text: Tr.tr("Wallpaper")
        }

        SelectRow {
            first: true
            label: Tr.tr("Wallpaper transition")
            subtext: Tr.tr("The effect when the wallpaper changes")
            menuItems: transitionItems.instances
            active: transitionItems.instances.find(i => i.value === Config.background.wallpaperTransition) ?? null
            onSelected: item => GlobalConfig.background.wallpaperTransition = item.value

            Variants {
                id: transitionItems

                model: [
                {
                    value: 0,
                    text: Tr.trCtx("Chromatic bloom", "wallpaper transition")
                },
                {
                    value: 1,
                    text: Tr.trCtx("Colour distance", "wallpaper transition")
                },
                {
                    value: 2,
                    text: Tr.trCtx("Crossfade", "wallpaper transition")
                },
                {
                    value: 3,
                    text: Tr.trCtx("Crosshatch", "wallpaper transition")
                },
                {
                    value: 4,
                    text: Tr.trCtx("Crosswarp", "wallpaper transition")
                },
                {
                    value: 5,
                    text: Tr.trCtx("Directional", "wallpaper transition")
                },
                {
                    value: 6,
                    text: Tr.trCtx("Directional wipe", "wallpaper transition")
                },
                {
                    value: 7,
                    text: Tr.trCtx("Fade colour", "wallpaper transition")
                },
                {
                    value: 8,
                    text: Tr.trCtx("Glitch", "wallpaper transition")
                },
                {
                    value: 9,
                    text: Tr.trCtx("Glitch displace", "wallpaper transition")
                },
                {
                    value: 10,
                    text: Tr.trCtx("Heat melt", "wallpaper transition")
                },
                {
                    value: 11,
                    text: Tr.trCtx("Ink splash", "wallpaper transition")
                },
                {
                    value: 12,
                    text: Tr.trCtx("Inkwell drop", "wallpaper transition")
                },
                {
                    value: 13,
                    text: Tr.trCtx("Iris", "wallpaper transition")
                },
                {
                    value: 14,
                    text: Tr.trCtx("Morph", "wallpaper transition")
                },
                {
                    value: 15,
                    text: Tr.trCtx("Parametric glitch", "wallpaper transition")
                },
                {
                    value: 16,
                    text: Tr.trCtx("Perlin", "wallpaper transition")
                },
                {
                    value: 17,
                    text: Tr.trCtx("Pixelate", "wallpaper transition")
                },
                {
                    value: 18,
                    text: Tr.trCtx("Pixelfade wave", "wallpaper transition")
                },
                {
                    value: 19,
                    text: Tr.trCtx("Plasma flow", "wallpaper transition")
                },
                {
                    value: 20,
                    text: Tr.trCtx("Polka dots curtain", "wallpaper transition")
                },
                {
                    value: 21,
                    text: Tr.trCtx("Puzzle right", "wallpaper transition")
                },
                {
                    value: 22,
                    text: Tr.trCtx("Random squares", "wallpaper transition")
                },
                {
                    value: 23,
                    text: Tr.trCtx("Smoke", "wallpaper transition")
                },
                {
                    value: 24,
                    text: Tr.trCtx("Soft warp fade", "wallpaper transition")
                },
                {
                    value: 25,
                    text: Tr.trCtx("Voronoi shatter", "wallpaper transition")
                },
                {
                    value: 26,
                    text: Tr.trCtx("Zoom blur pull", "wallpaper transition")
                }
                ]

                MenuItem {
                    required property var modelData

                    text: modelData.text
                    value: modelData.value
                }
            }
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Wallpaper folder")
            subtext: Tr.tr("Where the wallpaper picker looks")
            value: GlobalConfig.paths.wallpaperDir
            onEditingFinished: v => {
                if (v.trim())
                    GlobalConfig.paths.wallpaperDir = v.trim();
            }
        }

        // A clock on the desktop
        SectionHeader {
            text: Tr.tr("Desktop clock")
        }

        ToggleRow {
            first: true
            last: !Config.background.desktopClock.enabled
            text: Tr.tr("Clock on the desktop")
            checked: Config.background.desktopClock.enabled
            onToggled: GlobalConfig.background.desktopClock.enabled = checked
        }

        SelectRow {
            visible: Config.background.desktopClock.enabled
            label: Tr.tr("Position")
            menuItems: [
                MenuItem {
                    text: Tr.trCtx("Top left", "screen position")
                    value: "top-left"
                },
                MenuItem {
                    text: Tr.trCtx("Top", "screen position")
                    value: "top-center"
                },
                MenuItem {
                    text: Tr.trCtx("Top right", "screen position")
                    value: "top-right"
                },
                MenuItem {
                    text: Tr.trCtx("Left", "screen position")
                    value: "middle-left"
                },
                MenuItem {
                    text: Tr.trCtx("Centre", "screen position")
                    value: "middle-center"
                },
                MenuItem {
                    text: Tr.trCtx("Right", "screen position")
                    value: "middle-right"
                },
                MenuItem {
                    text: Tr.trCtx("Bottom left", "screen position")
                    value: "bottom-left"
                },
                MenuItem {
                    text: Tr.trCtx("Bottom", "screen position")
                    value: "bottom-center"
                },
                MenuItem {
                    text: Tr.trCtx("Bottom right", "screen position")
                    value: "bottom-right"
                }
            ]
            active: menuItems.find(i => i.value === Config.background.desktopClock.position) ?? null
            onSelected: item => GlobalConfig.background.desktopClock.position = item.value
        }

        SliderRow {
            visible: Config.background.desktopClock.enabled
            icon: "format_size"
            label: Tr.tr("Clock size")
            valueLabel: `${Math.round(Config.background.desktopClock.scale * 100)}%`
            // 50% .. 300%
            value: (Config.background.desktopClock.scale - 0.5) / 2.5
            onMoved: v => GlobalConfig.background.desktopClock.scale = Math.round((0.5 + v * 2.5) * 20) / 20
        }

        ToggleRow {
            visible: Config.background.desktopClock.enabled
            text: Tr.tr("Dark text")
            subtext: Tr.tr("For light wallpapers")
            checked: Config.background.desktopClock.invertColors
            onToggled: GlobalConfig.background.desktopClock.invertColors = checked
        }

        ToggleRow {
            visible: Config.background.desktopClock.enabled
            text: Tr.tr("Background behind the clock")
            checked: Config.background.desktopClock.background.enabled
            onToggled: GlobalConfig.background.desktopClock.background.enabled = checked
        }

        ToggleRow {
            visible: Config.background.desktopClock.enabled
            last: true
            text: Tr.tr("Shadow")
            checked: Config.background.desktopClock.shadow.enabled
            onToggled: GlobalConfig.background.desktopClock.shadow.enabled = checked
        }

        // Bars that move with the music, on the wallpaper
        SectionHeader {
            text: Tr.tr("Audio visualiser")
        }

        ToggleRow {
            first: true
            last: !Config.background.visualiser.enabled
            text: Tr.tr("Visualiser on the desktop")
            subtext: Tr.tr("Bars at the bottom of the wallpaper that move with what's playing")
            checked: Config.background.visualiser.enabled
            onToggled: GlobalConfig.background.visualiser.enabled = checked
        }

        ToggleRow {
            visible: Config.background.visualiser.enabled
            text: Tr.tr("Hide when windows cover the desktop")
            checked: Config.background.visualiser.autoHide
            onToggled: GlobalConfig.background.visualiser.autoHide = checked
        }

        ToggleRow {
            visible: Config.background.visualiser.enabled
            last: true
            text: Tr.tr("Blur")
            checked: Config.background.visualiser.blur
            onToggled: GlobalConfig.background.visualiser.blur = checked
        }
    }
}
