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

    // A live wallpaper is on: chosen, and the renderer running (or Caelestia's
    // own wallpaper hidden for it, while it starts)
    readonly property bool live: !!LiveWallpaper.current && (LiveWallpaper.running || !Config.background.wallpaperEnabled)
    readonly property bool livePlaylist: LiveWallpaper.current.startsWith("playlist:")

    title: Tr.tr("Wallpaper & style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        // Rows sit close like on every page; the preview and its buttons get
        // their room from their own margins
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
                onClicked: root.nState.openSubPage(3) // Colours page
            }

            IconTextButton {
                icon: "auto_awesome"
                text: Tr.tr("Nebula")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(9) // Nebula: desktop widgets, glass
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

        ToggleRow {
            text: Tr.tr("Desktop icons")
            subtext: Tr.tr("Show what's in the Desktop folder on the desktop")
            checked: Config.background.desktopIcons
            onToggled: GlobalConfig.background.desktopIcons = checked
        }

        ToggleRow {
            text: Tr.tr("Transparency")
            // TRANSLATORS: %1/%2 = opacity values from 0 to 1 for the base surface and layered surfaces
            subtext: Tr.tr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        ToggleRow {
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
            text: Tr.tr("Shadow")
            checked: Config.background.desktopClock.shadow.enabled
            onToggled: GlobalConfig.background.desktopClock.shadow.enabled = checked
        }

        // Bars that move with the music, on the wallpaper
        SectionHeader {
            text: Tr.tr("Audio visualiser")
        }

        ToggleRow {
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


        // Every blur setting, in one place: what each one blurs is in its text. Windows' blur is
        // Hyprland's (decoration:blur); the shell's surfaces can have their own strength (layer
        // rules blur_size / blur_passes, from the shell's own Hyprland build), 0 = as windows.
        SectionHeader {
            text: Tr.tr("Blur")
        }

        ToggleRow {
            text: Tr.tr("Blur")
            subtext: Tr.tr("Frosted glass behind everything see-through: windows, panels, the bar, widgets, title bars")
            checked: HyprSettings.value("decoration:blur:enabled", true)
            onToggled: HyprSettings.setOption("decoration:blur:enabled", checked)
        }

        SelectRow {
            visible: root.blurOn
            label: Tr.tr("Look")
            subtext: Tr.tr("Sets windows' strength (and so everything that follows it)")
            menuItems: [nebulaBlur, strongBlur]
            active: root.winBlurSize === 4 && root.winBlurPasses === 1 ? nebulaBlur : root.winBlurSize === 8 && root.winBlurPasses === 2 ? strongBlur : null
            fallbackText: Tr.tr("Your own")
            onSelected: item => {
                HyprSettings.setOption("decoration:blur:size", item.value[0]);
                HyprSettings.setOption("decoration:blur:passes", item.value[1]);
            }

            MenuItem {
                id: nebulaBlur

                text: Tr.tr("Nebula: soft, shapes show through")
                value: [4, 1]
            }

            MenuItem {
                id: strongBlur

                text: Tr.tr("Strong: frosted")
                value: [8, 2]
            }
        }

        BlurRow {
            visible: root.blurOn
            label: Tr.tr("Windows")
            subtext: Tr.tr("See-through windows; also everything below set to \"as windows\"")
            size: root.winBlurSize
            passes: root.winBlurPasses
            minimum: 1
            onSizeMoved: v => HyprSettings.setOption("decoration:blur:size", v)
            onPassesMoved: v => HyprSettings.setOption("decoration:blur:passes", v)
        }

        BlurRow {
            visible: root.blurOn
            label: Tr.tr("Panels and bar")
            subtext: Tr.tr("The shell's bar, dashboard, launcher, sidebar, notifications and popouts")
            size: GlobalConfig.appearance.blur.shellSize
            passes: GlobalConfig.appearance.blur.shellPasses
            onSizeMoved: v => GlobalConfig.appearance.blur.shellSize = v
            onPassesMoved: v => GlobalConfig.appearance.blur.shellPasses = v
        }

        BlurRow {
            visible: root.blurOn
            label: Tr.tr("Desktop widgets")
            subtext: Tr.tr("Nebula's widgets, their menus and the widgets corner")
            size: GlobalConfig.appearance.blur.widgetsSize
            passes: GlobalConfig.appearance.blur.widgetsPasses
            onSizeMoved: v => GlobalConfig.appearance.blur.widgetsSize = v
            onPassesMoved: v => GlobalConfig.appearance.blur.widgetsPasses = v
        }

        ToggleRow {
            visible: root.blurOn && HyprSettings.value("plugin:hyprflow:bar_blur", null) !== null
            text: Tr.tr("Title bars")
            subtext: Tr.tr("Desktop mode's title bars, at windows' strength")
            checked: HyprSettings.value("plugin:hyprflow:bar_blur", true)
            onToggled: HyprSettings.setHyprflow("bar_blur", checked)
        }

        ToggleRow {
            visible: root.blurOn && Config.background.visualiser.enabled
            text: Tr.tr("Audio visualiser")
            subtext: Tr.tr("The visualiser's bars on the desktop")
            checked: Config.background.visualiser.blur
            onToggled: GlobalConfig.background.visualiser.blur = checked
        }
    }

    readonly property bool blurOn: HyprSettings.value("decoration:blur:enabled", true)
    readonly property int winBlurSize: HyprSettings.value("decoration:blur:size", 8)
    readonly property int winBlurPasses: HyprSettings.value("decoration:blur:passes", 2)

    // Strength (blur size) and quality (passes) of one kind of surface; 0 = "as windows"
    component BlurRow: ColumnLayout {
        id: blurRow

        property string label
        property string subtext
        property int size
        property int passes
        property int minimum: 0

        signal sizeMoved(int v)
        signal passesMoved(int v)

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall / 2

        StepperRow {
            label: blurRow.label
            subtext: blurRow.minimum === 0 && blurRow.size === 0 ? blurRow.subtext + " · " + Tr.tr("strength as windows") : blurRow.subtext + " · " + Tr.tr("strength")
            value: blurRow.size
            from: blurRow.minimum
            to: 20
            stepSize: 1
            onMoved: v => blurRow.sizeMoved(v)
        }

        StepperRow {
            label: Tr.tr("%1: quality").arg(blurRow.label)
            subtext: blurRow.minimum === 0 && blurRow.passes === 0 ? Tr.tr("Passes: more is smoother and costs more · as windows") : Tr.tr("Passes: more is smoother and costs more")
            value: blurRow.passes
            from: blurRow.minimum
            to: 6
            stepSize: 1
            onMoved: v => blurRow.passesMoved(v)
        }
    }
}
