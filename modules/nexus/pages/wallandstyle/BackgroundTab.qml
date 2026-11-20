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
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // A live wallpaper is on: chosen, and the renderer running (or Caelestia's
    // own wallpaper hidden for it, while it starts)
    readonly property bool live: !!LiveWallpaper.current && (LiveWallpaper.running || !Config.background.wallpaperEnabled)
    readonly property bool livePlaylist: LiveWallpaper.current.startsWith("playlist:")

    signal openColours

    title: Tr.tr("Background")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ClipRect {
            id: wallWrapper

            Layout.bottomMargin: Tokens.spacing.large
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
                opacity: Config.background.wallpaperEnabled || root.live ? 0 : 1
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

            // The live wallpaper: its preview, or the playlist's name
            Loader {
                anchors.fill: parent
                opacity: root.live ? 1 : 0
                active: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }

                sourceComponent: Item {
                    // The renderer's full-size frame (sharp); until it's saved, the
                    // wallpaper's own (small, animated) preview
                    Image {
                        id: liveFrame

                        anchors.fill: parent
                        source: LiveWallpaper.currentFrame ? `file://${LiveWallpaper.currentFrame}` : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 1280
                    }

                    // Until the frame is there: the still (not the animated
                    // preview: an AnimatedImage decodes every frame first, which
                    // made the settings open with a lag)
                    Image {
                        anchors.fill: parent
                        visible: liveFrame.status !== Image.Ready
                        source: visible && LiveWallpaper.currentInfo ? `file://${LiveWallpaper.currentInfo.still || LiveWallpaper.currentInfo.preview}` : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 640
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.livePlaylist && !LiveWallpaper.currentInfo
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "playlist_play"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.extraLarge
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: LiveWallpaper.current.replace(/^playlist:/, "")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.large
                        }
                    }

                    StyledRect {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Tokens.padding.small
                        implicitWidth: liveBadge.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: liveBadge.implicitHeight + Tokens.padding.extraSmall * 2
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        StyledText {
                            id: liveBadge

                            anchors.centerIn: parent
                            text: (root.livePlaylist ? Tr.tr("Playlist %1 · ").arg(LiveWallpaper.current.replace(/^playlist:/, "")) : "") + (LiveWallpaper.paused ? Tr.tr("Live · paused") : Tr.tr("Live"))
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.label.medium
                        }
                    }
                }
            }
        }

        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.large
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
                disabled: !Config.background.wallpaperEnabled && !root.live
                onClicked: root.nState.openSubPage(1) // Wallpaper page
            }

            IconTextButton {
                icon: "animated_images"
                text: Tr.tr("Live")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(4) // Live wallpapers
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
                onClicked: root.openColours()
            }
        }

        ToggleRow {
            text: Tr.tr("Display wallpaper")
            checked: Config.background.wallpaperEnabled || root.live
            onToggled: {
                // Off means no wallpaper at all, a live one included
                if (!checked && root.live)
                    LiveWallpaper.stop();
                GlobalConfig.background.wallpaperEnabled = checked;
            }
        }

        SectionHeader {
            text: Tr.tr("Wallpaper")
        }

        SelectRow {
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

        FolderPickerRow {
            label: Tr.tr("Wallpaper folder")
            subtext: Tr.tr("Where the wallpaper picker looks")
            value: GlobalConfig.paths.wallpaperDir
            defaultValue: `${Paths.pictures}/Wallpapers`
            canReset: true
            onPicked: path => GlobalConfig.paths.wallpaperDir = path
            onResetClicked: GlobalConfig.paths.wallpaperDir = `${Paths.pictures}/Wallpapers`
        }
    }
}
