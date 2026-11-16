pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Dashboard > Media, small (the island's page size): cover, title and artist, progress, controls
Item {
    id: root

    readonly property var player: Players.active
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0

    function mmss(sec: real): string {
        const t = Math.max(0, Math.floor(sec || 0));
        return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
    }

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    Timer {
        running: root.player?.isPlaying ?? false
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium
        visible: !!root.player

        ClipRect {
            Layout.preferredWidth: height
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh

            MaterialIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "music_note"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.large
            }

            Image {
                id: art

                anchors.fill: parent
                source: Players.getArtUrl(root.player)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 320
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || Tr.tr("Unknown title")
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || Players.getIdentity(root.player)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Colours.palette.m3secondaryContainer

                StyledRect {
                    width: parent.width * Math.max(0, Math.min(1, root.progress))
                    height: parent.height
                    radius: 2
                    color: Colours.palette.m3primary
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: root.mmss(root.player?.position ?? 0)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    type: IconButton.Text
                    icon: "skip_previous"
                    disabled: !(root.player?.canGoPrevious ?? false)
                    onClicked: root.player?.previous()
                }

                IconButton {
                    type: IconButton.Filled
                    icon: root.player?.isPlaying ? "pause" : "play_arrow"
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    type: IconButton.Text
                    icon: "skip_next"
                    disabled: !(root.player?.canGoNext ?? false)
                    onClicked: root.player?.next()
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.mmss(root.player?.length ?? 0)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.player
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "music_off"
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.large
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("Nothing playing")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }
    }
}
