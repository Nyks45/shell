pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// The island's overview: what's useful right now, nothing the pill or the other pages already
// show. What's playing (with its controls), the system at a glance, the latest notifications
// (a click opens them), and the pinned apps to start.
Item {
    id: root

    required property ScreenState screenState

    readonly property var player: Players.active

    // The lyrics follow what's playing (like the dashboard's lyrics)
    readonly property var _lyricsTrack: {
        const p = Players.active;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        return 0;
    }

    Timer {
        running: root.player?.isPlaying ?? false
        interval: 500
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
    readonly property var latest: Notifs.notClosed.slice(0, 2)
    readonly property var pinned: Array.from(TaskbarApps.pinned).map(id => DesktopEntries.byId(id)).filter(e => !!e).slice(0, 8)

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Gpu
    }

    ServiceRef {
        service: Memory
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            // What's playing: a compact row (cover, song, controls) and the synced lyrics under it
            Card {
                Layout.preferredWidth: 1
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ClipRect {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: Tokens.rounding.medium
                            color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.7)

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                text: "music_note"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                            }

                            Image {
                                id: art

                                anchors.fill: parent
                                source: root.player ? Players.getArtUrl(root.player) : (Music.last?.art ?? "")
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 88
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                PlayingBars {
                                    visible: root.player?.isPlaying ?? false
                                    playing: visible
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.player?.trackTitle || Music.last?.title || Tr.tr("Nothing playing")
                                    font: Tokens.font.label.large
                                    elide: Text.ElideRight
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.player ? (root.player.trackArtist || Players.getIdentity(root.player)) : Music.last ? Tr.tr("Last played · %1").arg(Music.last.artist) : Tr.tr("Play your liked songs")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        // (nothing playing: play continues the last song, starting Spotify)
                        StyledRect {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 17
                            color: Colours.palette.m3primary

                            StateLayer {
                                radius: 17
                                color: Colours.palette.m3onPrimary
                                onClicked: Music.toggle()
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.player?.isPlaying ? "pause" : "play_arrow"
                                color: Colours.palette.m3onPrimary
                                fontStyle: Tokens.font.icon.small
                                fill: 1
                            }
                        }

                        IconButton {
                            type: IconButton.Text
                            icon: "skip_next"
                            disabled: !root.player
                            onClicked: root.player?.next()
                        }
                    }

                    // The lyrics: the line being sung, with the one before and after
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        readonly property var lines: Lyrics.lyrics
                        // (before the first line: -1, a note in the middle and the first line under it)
                        readonly property bool ready: !!root.player && Lyrics.hasLyrics && lines.length > 0
                        readonly property int at: ready ? Lyrics.indexForTime(root.player.position) : -1

                        Column {
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: 2
                            visible: parent.ready

                            Repeater {
                                model: [-1, 0, 1]

                                StyledText {
                                    required property int modelData
                                    readonly property int line: parent.parent.at + modelData

                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: line < 0 ? (modelData === 0 ? "♪" : "") : (parent.parent.lines[line] ?? "")
                                    color: modelData === 0 ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                    opacity: modelData === 0 ? 1 : 0.5
                                    font: modelData === 0 ? Tokens.font.label.large : Tokens.font.label.small
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: !parent.ready
                            // (nothing playing: what play does, not an empty card)
                            text: !root.player ? (Music.last ? Tr.tr("Play continues where you left off") : Tr.tr("Play your liked songs")) : Lyrics.loading ? Tr.tr("Finding the lyrics…") : Tr.tr("No lyrics for this song")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            // The system at a glance
            Card {
                Layout.preferredWidth: 1
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    Stat {
                        icon: "memory"
                        label: Tr.tr("CPU")
                        value: Cpu.percentage
                        extra: Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)}°` : ""
                    }

                    Stat {
                        icon: "developer_board"
                        label: Tr.tr("GPU")
                        value: Gpu.percentage
                        extra: Gpu.temperature > 0 ? `${Math.round(Gpu.temperature)}°` : ""
                        colour: Colours.palette.m3secondary
                    }

                    Stat {
                        icon: "memory_alt"
                        label: Tr.tr("RAM")
                        value: Memory.percentage
                        extra: `${(Memory.used / 1048576).toFixed(1)} GB`
                        colour: Colours.palette.m3tertiary
                    }
                }
            }
        }

        // The latest notifications: a click opens them
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: notifCol.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                radius: Tokens.rounding.large
                onClicked: root.screenState.dashboardRequest = "notifications"
            }

            ColumnLayout {
                id: notifCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.medium
                spacing: 2

                Repeater {
                    model: root.latest

                    RowLayout {
                        id: nrow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: nrow.modelData.hints?.["x-caelestia-icon"] || "notifications"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            text: nrow.modelData.appName || Tr.tr("App")
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: nrow.modelData.summary
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: nrow.modelData.timeStr
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }
                }

                StyledText {
                    visible: root.latest.length === 0
                    text: Tr.tr("No notifications")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }
        }

        // The pinned apps
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: root.pinned.length > 0
            spacing: Tokens.spacing.small

            Repeater {
                model: root.pinned

                StyledRect {
                    id: app

                    required property var modelData

                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Tokens.rounding.large
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)

                    StateLayer {
                        radius: Tokens.rounding.large
                        onClicked: {
                            TaskbarApps.launch({
                                entry: app.modelData
                            });
                            root.screenState.dashboard = false;
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 24
                        asynchronous: true
                        source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                    }
                }
            }
        }
    }

    component Card: StyledRect {
        Layout.fillHeight: true
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)
    }

    // A usage line: icon, name, a slim bar and its number
    component Stat: RowLayout {
        id: stat

        property string icon
        property string label
        property real value
        property string extra
        property color colour: Colours.palette.m3primary

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: stat.icon
            color: stat.colour
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            Layout.preferredWidth: 34
            text: stat.label
            font: Tokens.font.label.medium
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Colours.tPalette.m3surfaceContainerHighest

            StyledRect {
                width: parent.width * Math.max(0, Math.min(1, stat.value))
                height: parent.height
                radius: 3
                color: stat.colour

                Behavior on width {
                    Anim {}
                }
            }
        }

        StyledText {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(stat.value * 100)}%`
            font: Tokens.font.label.medium
        }

        StyledText {
            Layout.preferredWidth: 46
            horizontalAlignment: Text.AlignRight
            text: stat.extra
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
