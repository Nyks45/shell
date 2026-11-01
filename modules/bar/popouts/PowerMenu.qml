pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

// The power menu, opened from the bar's power button: the session gif, then
// shut down / restart / sleep / log out as labelled tiles. Everything comes in
// one after another once the popout has grown out of the bar.
ColumnLayout {
    id: root

    required property PopoutState popouts

    function close(): void {
        popouts.hasCurrent = false;
    }

    spacing: Tokens.spacing.medium

    // Keyboard: the menu takes focus once shown, but nothing is selected until
    // an arrow or Tab (so a stray Enter can't shut down); then Enter runs it
    Component.onCompleted: {
        Qt.callLater(() => root.forceActiveFocus());
        entrance.start();
    }

    Keys.onPressed: event => {
        if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Tab, Qt.Key_Backtab].includes(event.key)) {
            shutdown.forceActiveFocus();
            event.accepted = true;
        }
    }

    // Staggered entrance: the gif first, then the tiles in reading order
    SequentialAnimation {
        id: entrance

        PauseAnimation {
            duration: 40
        }
        ParallelAnimation {
            Anim {
                target: gif
                property: "opacity"
                to: 1
                type: Anim.DefaultEffects
            }
            Anim {
                target: gif
                property: "scale"
                to: 1
                type: Anim.FastSpatial
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 50
                }
                TileIn {
                    tile: shutdown
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 90
                }
                TileIn {
                    tile: reboot
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 130
                }
                TileIn {
                    tile: sleep
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 170
                }
                TileIn {
                    tile: logout
                }
            }
        }
    }

    Loader {
        id: gif

        Layout.alignment: Qt.AlignHCenter
        active: Config.paths.sessionGif.trim() !== ""
        visible: active
        opacity: 0
        scale: 0.8

        sourceComponent: AnimatedImage {
            width: Tokens.sizes.session.button * 1.2
            height: Tokens.sizes.session.button * 1.2
            sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)

            playing: visible
            asynchronous: true
            speed: Config.general.sessionGifSpeed
            source: Paths.absolutePath(Config.paths.sessionGif)
            fillMode: AnimatedImage.PreserveAspectFit
        }
    }

    GridLayout {
        Layout.alignment: Qt.AlignHCenter
        columns: 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small

        Tile {
            id: shutdown

            icon: Config.session.icons.shutdown
            label: Tr.tr("Shut down")
            command: Config.session.commands.shutdown

            KeyNavigation.right: reboot
            KeyNavigation.down: sleep
            KeyNavigation.tab: reboot
            KeyNavigation.backtab: logout
        }

        Tile {
            id: reboot

            icon: Config.session.icons.reboot
            label: Tr.tr("Restart")
            command: Config.session.commands.reboot

            KeyNavigation.left: shutdown
            KeyNavigation.down: logout
            KeyNavigation.tab: sleep
            KeyNavigation.backtab: shutdown
        }

        Tile {
            id: sleep

            icon: Config.session.icons.sleep
            label: Tr.tr("Sleep")
            command: Config.session.commands.sleep

            KeyNavigation.right: logout
            KeyNavigation.up: shutdown
            KeyNavigation.tab: logout
            KeyNavigation.backtab: reboot
        }

        Tile {
            id: logout

            icon: Config.session.icons.logout
            label: Tr.tr("Log out")
            command: Config.session.commands.logout

            KeyNavigation.left: sleep
            KeyNavigation.up: reboot
            KeyNavigation.tab: shutdown
            KeyNavigation.backtab: sleep
        }
    }

    component TileIn: ParallelAnimation {
        required property Item tile

        Anim {
            target: tile
            property: "opacity"
            to: 1
            type: Anim.DefaultEffects
        }
        Anim {
            target: tile
            property: "lift"
            to: 0
            type: Anim.FastSpatial
        }
    }

    component Tile: StyledRect {
        id: tile

        required property string icon
        required property string label
        required property list<string> command
        // Entrance offset (rises into place)
        property real lift: Tokens.spacing.large

        function exec(): void {
            root.close();
            if (!SessionManager.exec(command))
                Quickshell.execDetached(command);
        }

        implicitWidth: Math.round(Tokens.sizes.session.button * 1.3)
        implicitHeight: Math.round(Tokens.sizes.session.button * 1.05)
        opacity: 0
        transform: Translate {
            y: tile.lift
        }

        radius: stateLayer.pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.large
        color: activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

        Behavior on radius {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Keys.onEnterPressed: exec()
        Keys.onReturnPressed: exec()
        Keys.onSpacePressed: exec()

        StateLayer {
            id: stateLayer

            anchors.fill: parent
            radius: tile.radius
            color: tile.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            onClicked: tile.exec()
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: tile.icon
                color: tile.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.builders.large.scale(1.1).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tile.label
                color: tile.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }
    }
}
