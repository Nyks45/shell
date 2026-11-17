pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// The island's power page: the session picture (Settings > Panels > Power menu, the same GIF) in
// a circle beside who's signed in and the uptime, then lock, sleep, log out, restart and shut
// down as one row of buttons. They run the power menu's commands.
Item {
    id: root

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.large

            ClipRect {
                implicitWidth: 112
                implicitHeight: 112
                radius: 56
                color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: Config.paths.sessionGif.trim() !== ""
                    source: visible ? Paths.absolutePath(Config.paths.sessionGif) : ""
                    playing: root.visible
                    asynchronous: true
                    speed: Config.general.sessionGifSpeed
                    fillMode: AnimatedImage.PreserveAspectFit
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("See you, %1").arg(SysInfo.user)
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: "schedule"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Tr.tr("Up %1").arg(SysInfo.uptime)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: "computer"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: SysInfo.hostname
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Action {
                icon: "lock"
                text: Tr.tr("Lock")
                onRun: Quickshell.execDetached(["loginctl", "lock-session"])
            }

            Action {
                icon: Config.session.icons.sleep
                text: Tr.tr("Sleep")
                onRun: Quickshell.execDetached(Config.session.commands.sleep)
            }

            Action {
                icon: Config.session.icons.logout
                text: Tr.tr("Log out")
                onRun: Quickshell.execDetached(Config.session.commands.logout)
            }

            Action {
                icon: Config.session.icons.reboot
                text: Tr.tr("Restart")
                onRun: Quickshell.execDetached(Config.session.commands.reboot)
            }

            Action {
                icon: Config.session.icons.shutdown
                text: Tr.tr("Shut down")
                danger: true
                onRun: Quickshell.execDetached(Config.session.commands.shutdown)
            }
        }
    }

    // An action: its icon in a soft square that rounds on hover, its name under it
    component Action: ColumnLayout {
        id: act

        property string icon
        property string text
        property bool danger

        signal run

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.maximumWidth: 10000
        spacing: Tokens.spacing.extraSmall

        StyledRect {
            id: square

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 64
            implicitHeight: 56
            radius: actArea.containsMouse ? height / 2 : Tokens.rounding.large
            color: act.danger ? (actArea.containsMouse ? Colours.palette.m3error : Colours.palette.m3errorContainer) : (actArea.containsMouse ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45))

            Behavior on radius {
                Anim {}
            }

            Behavior on color {
                CAnim {}
            }

            StateLayer {
                id: actArea

                color: act.danger ? Colours.palette.m3onError : Colours.palette.m3onPrimary
                onClicked: act.run()
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: act.icon
                color: act.danger ? (actArea.containsMouse ? Colours.palette.m3onError : Colours.palette.m3onErrorContainer) : (actArea.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant)
                fontStyle: Tokens.font.icon.medium
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: act.text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
