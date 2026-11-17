pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import "../media"

// The island's music page. Left: what's playing (any player; a switcher when there are several),
// or the last track when nothing is (play starts Spotify hidden and resumes it). Right: the
// Spotify library (services/Music.qml): playlists and recently played; a playlist opens to its
// songs. Not logged in: a button to log in.
Item {
    id: root

    property var screenState: null
    readonly property var player: Players.active
    readonly property bool hasPlayer: !!player
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0
    // "playlists", "recent", "lyrics" or "search"
    property string libTab: "playlists"

    function mmss(sec: real): string {
        const t = Math.max(0, Math.floor(sec || 0));
        return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
    }

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    Component.onCompleted: {
        if (Music.loggedIn && Music.playlists.length === 0)
            Music.loadLibrary();
    }

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

        // What's playing
        ArtBackdrop {
            id: nowCard

            Layout.preferredWidth: 220
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            source: art.source

            ColumnLayout {
                id: nowCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                // Several players: which one
                Row {
                    id: switcher

                    Layout.alignment: Qt.AlignHCenter
                    visible: Players.list.length > 1
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: Players.list

                        StyledRect {
                            id: chip

                            required property var modelData
                            readonly property bool chosen: modelData === root.player

                            implicitWidth: chipText.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: chipText.implicitHeight + 6
                            radius: height / 2
                            color: chosen
                                ? (nowCard.hasArt ? nowCard.accent : Colours.palette.m3primary)
                                : (nowCard.hasArt ? Qt.rgba(1, 1, 1, 0.14) : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6))

                            StateLayer {
                                radius: chip.height / 2
                                onClicked: Players.manualActive = chip.modelData
                            }

                            StyledText {
                                id: chipText

                                anchors.centerIn: parent
                                text: Players.getIdentity(chip.modelData)
                                color: chip.chosen
                                    ? (nowCard.hasArt ? nowCard.accentText : Colours.palette.m3onPrimary)
                                    : (nowCard.hasArt ? Qt.rgba(1, 1, 1, 0.78) : Colours.palette.m3onSurfaceVariant)
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }

                ClipRect {
                    Layout.alignment: Qt.AlignHCenter
                    // (what's left once the rest is in: the switcher, the song, the progress and
                    // the controls always fit)
                    Layout.preferredWidth: Math.max(40, Math.min(118, nowCol.height - songCol.implicitHeight - progressRow.implicitHeight - controlsRow.implicitHeight - (switcher.visible ? switcher.implicitHeight + nowCol.spacing : 0) - nowCol.spacing * 3))
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: Tokens.rounding.large
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)

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
                        source: root.hasPlayer ? Players.getArtUrl(root.player) : (Music.last?.art ?? "")
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 240
                        opacity: root.hasPlayer ? 1 : 0.6
                    }
                }

                ColumnLayout {
                    id: songCol

                    Layout.fillWidth: true
                    spacing: 0

                    PlayingBars {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 2
                        visible: root.player?.isPlaying ?? false
                        playing: visible
                        colour: nowCard.hasArt ? nowCard.accent : Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.hasPlayer ? (root.player.trackTitle || Tr.tr("Unknown title")) : (Music.last?.title ?? Tr.tr("Nothing playing"))
                        color: nowCard.hasArt ? "#ffffff" : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.hasPlayer ? (root.player.trackArtist || Players.getIdentity(root.player)) : Music.last ? Tr.tr("Last played · %1").arg(Music.last.artist) : Tr.tr("Play your liked songs")
                        color: nowCard.hasArt ? Qt.rgba(1, 1, 1, 0.72) : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                // Progress
                RowLayout {
                    id: progressRow

                    Layout.fillWidth: true
                    visible: root.hasPlayer
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: root.mmss(root.player?.position ?? 0)
                        color: nowCard.hasArt ? Qt.rgba(1, 1, 1, 0.72) : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: nowCard.hasArt ? Qt.rgba(1, 1, 1, 0.22) : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.7)

                        StyledRect {
                            width: parent.width * Math.max(0, Math.min(1, root.progress))
                            height: parent.height
                            radius: 2
                            color: nowCard.hasArt ? nowCard.accent : Colours.palette.m3primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: event => {
                                if (root.player?.canSeek)
                                    root.player.position = root.player.length * Math.max(0, Math.min(1, (event.x - 6) / (width - 12)));
                            }
                        }
                    }

                    StyledText {
                        text: root.mmss(root.player?.length ?? 0)
                        color: nowCard.hasArt ? Qt.rgba(1, 1, 1, 0.72) : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                // Controls
                Row {
                    id: controlsRow

                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        type: IconButton.Text
                        icon: "skip_previous"
                        disabled: !(root.player?.canGoPrevious ?? false)
                        inactiveOnColour: nowCard.hasArt ? "#ffffff" : Colours.palette.m3onSurfaceVariant
                        activeOnColour: nowCard.hasArt ? nowCard.accent : Colours.palette.m3primary
                        onClicked: root.player?.previous()
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        type: IconButton.Filled
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        inactiveColour: nowCard.hasArt ? nowCard.accent : Colours.palette.m3primary
                        activeColour: inactiveColour
                        inactiveOnColour: nowCard.hasArt ? nowCard.accentText : Colours.palette.m3onPrimary
                        activeOnColour: inactiveOnColour
                        onClicked: Music.toggle()
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        type: IconButton.Text
                        icon: "skip_next"
                        disabled: !(root.player?.canGoNext ?? false)
                        inactiveOnColour: nowCard.hasArt ? "#ffffff" : Colours.palette.m3onSurfaceVariant
                        activeOnColour: nowCard.hasArt ? nowCard.accent : Colours.palette.m3primary
                        onClicked: root.player?.next()
                    }
                }
            }
        }

        // The Spotify library
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.small
                visible: Music.loggedIn || root.libTab === "lyrics"

                // Header: Playlists / Recent, or the opened playlist with back and play all
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        visible: !!Music.openList
                        type: IconButton.Text
                        icon: "arrow_back"
                        onClicked: Music.openList = null
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !!Music.openList
                        text: Music.openList?.name ?? ""
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: Music.openList ? [] : [
                            {
                                key: "playlists",
                                text: Tr.tr("Playlists")
                            },
                            {
                                key: "recent",
                                text: Tr.tr("Recent")
                            },
                            {
                                key: "lyrics",
                                text: Tr.tr("Lyrics")
                            },
                            {
                                key: "search",
                                icon: "search"
                            }
                        ]

                        StyledRect {
                            id: libChip

                            required property var modelData
                            readonly property bool chosen: root.libTab === modelData.key

                            implicitWidth: modelData.icon ? implicitHeight : libText.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: libText.implicitHeight + Tokens.padding.extraSmall * 2
                            radius: height / 2
                            color: chosen ? Colours.palette.m3primary : "transparent"

                            StateLayer {
                                radius: libChip.height / 2
                                onClicked: {
                                    root.libTab = libChip.modelData.key;
                                    if (libChip.modelData.key === "search")
                                        Qt.callLater(() => searchField.forceActiveFocus());
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: !!libChip.modelData.icon
                                text: libChip.modelData.icon ?? ""
                                color: libChip.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                            }

                            StyledText {
                                id: libText

                                anchors.centerIn: parent
                                text: libChip.modelData.text ?? ""
                                opacity: libChip.modelData.icon ? 0 : 1
                                color: libChip.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.medium
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: !Music.openList
                    }

                    IconButton {
                        visible: !!Music.openList
                        type: IconButton.Filled
                        icon: "play_arrow"
                        onClicked: Music.play(Music.openList.context || `spotify:playlist:${Music.openList.id}`)
                    }
                }

                // A search of Spotify: songs, then artists, albums and playlists
                SearchBar {
                    id: searchField

                    Layout.fillWidth: true
                    visible: root.libTab === "search" && !Music.openList
                    placeholderText: Tr.tr("Songs, artists, albums")
                    font: Tokens.font.body.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small
                    bg.color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)
                    Component.onCompleted: text = Music.query
                    onTextChanged: Music.search(text)
                    // (typing needs the keyboard: the island stays open while it's used)
                    onActiveFocusChanged: {
                        if (activeFocus && root.screenState)
                            root.screenState.dashboardSticky = true;
                    }
                }

                // The lyrics of what's playing (synced, like the dashboard's)
                LyricList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.libTab === "lyrics" && !Music.openList
                }

                ListView {
                    id: lib

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !(root.libTab === "lyrics" && !Music.openList)
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: Music.openList ? (Music.openList.tracks ?? []) : root.libTab === "recent" ? Music.recent : root.libTab === "search" ? Music.results : Music.playlists

                    delegate: StyledRect {
                        id: row

                        required property var modelData
                        readonly property bool isList: !Music.openList && root.libTab === "playlists"
                        readonly property bool isHeader: !!modelData.header
                        readonly property string kind: modelData.kind ?? ""

                        width: lib.width
                        implicitHeight: isHeader ? 24 : 42
                        radius: Tokens.rounding.medium
                        color: rowLayer.containsMouse ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6) : "transparent"

                        StyledText {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: Tokens.padding.small
                            visible: row.isHeader
                            text: row.modelData.header ?? ""
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.medium
                        }

                        StateLayer {
                            id: rowLayer

                            visible: !row.isHeader
                            radius: Tokens.rounding.medium
                            onClicked: {
                                if (row.isList)
                                    Music.openPlaylist(row.modelData);
                                else
                                    Music.play(row.modelData.uri);
                            }
                        }

                        RowLayout {
                            visible: !row.isHeader
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            ClipRect {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: row.kind === "artist" ? 17 : Tokens.rounding.small
                                color: row.modelData.id === "liked" ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.7)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: rowArt.status !== Image.Ready
                                    text: row.modelData.id === "liked" ? "favorite" : row.isList || row.kind === "playlist" ? "queue_music" : row.kind === "artist" ? "person" : row.kind === "album" ? "album" : "music_note"
                                    color: row.modelData.id === "liked" ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.small
                                    fill: 1
                                }

                                Image {
                                    id: rowArt

                                    anchors.fill: parent
                                    source: row.modelData.image ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 68
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: -2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.name ?? ""
                                    font: Tokens.font.label.large
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.isList ? Tr.tr("%1 songs").arg(row.modelData.count ?? 0) : row.kind === "artist" ? Tr.tr("Artist") : row.kind === "album" ? Tr.tr("Album · %1").arg(row.modelData.artist ?? "") : row.kind === "playlist" ? Tr.tr("Playlist · %1").arg(row.modelData.artist ?? "") : (row.modelData.artist ?? "")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                }
                            }

                            MaterialIcon {
                                visible: rowLayer.containsMouse
                                text: row.isList ? "chevron_right" : "play_arrow"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.small
                                fill: 1
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.padding.large * 2
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: lib.count === 0
                        text: Music.openList ? (Music.openList.restricted ? Tr.tr("Spotify doesn't let apps list the songs of playlists you follow. Play it as a whole with ▶.") : Music.openList.loaded ? Tr.tr("No songs") : Tr.tr("Loading…")) : root.libTab === "search" ? (Music.searching ? Tr.tr("Searching…") : Music.query ? Tr.tr("Nothing found") : Tr.tr("Find a song to play")) : Music.loading ? Tr.tr("Loading…") : Tr.tr("Nothing here")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }
            }

            // Not logged in
            ColumnLayout {
                anchors.centerIn: parent
                visible: !Music.loggedIn && root.libTab !== "lyrics"
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "library_music"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("Your playlists, here")
                    font: Tokens.font.body.small
                }

                TextButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("Log in with Spotify")
                    type: TextButton.Filled
                    onClicked: Music.login()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: Music.error !== ""
                    text: Music.error
                    color: Colours.palette.m3error
                    font: Tokens.font.label.small
                }
            }
        }
    }

    component Card: StyledRect {
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)
    }
}
