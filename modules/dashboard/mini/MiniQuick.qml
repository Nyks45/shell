pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.components.controls
import qs.services

// The island's page from a click on its pill: quick settings and notifications, side by side
// as two panes switched left and right (the header, the wheel or a swipe)
Item {
    id: root

    // 0 quick settings, 1 notifications
    property int pane: 0
    readonly property var notifs: Notifs.notClosed

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        // Which pane
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            PaneButton {
                index: 0
                icon: "tune"
                text: Tr.tr("Quick settings")
            }

            PaneButton {
                index: 1
                icon: "notifications"
                text: root.notifs.length ? Tr.tr("Notifications (%1)").arg(root.notifs.length) : Tr.tr("Notifications")
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                visible: root.pane === 1 && root.notifs.length > 0
                type: IconButton.Text
                icon: "clear_all"
                onClicked: {
                    for (const n of root.notifs.slice())
                        n.close();
                }
            }
        }

        // The two panes, sliding
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            WheelHandler {
                acceptedDevices: PointerDevice.TouchPad
                orientation: Qt.Horizontal
                onWheel: event => {
                    if (event.angleDelta.x < -30)
                        root.pane = 1;
                    else if (event.angleDelta.x > 30)
                        root.pane = 0;
                }
            }

            Row {
                x: -root.pane * parent.width
                height: parent.height

                Behavior on x {
                    Anim {}
                }

                // Quick settings
                ColumnLayout {
                    width: parent.parent.width
                    height: parent.height
                    spacing: Tokens.spacing.small

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: Tokens.spacing.extraSmall
                        columnSpacing: Tokens.spacing.extraSmall

                        Tile {
                            icon: "wifi"
                            text: Tr.tr("Wi-Fi")
                            on: Nmcli.wifiEnabled
                            onToggled: Nmcli.toggleWifi()
                        }

                        Tile {
                            icon: "bluetooth"
                            text: Tr.tr("Bluetooth")
                            on: Bluetooth.defaultAdapter?.enabled ?? false
                            onToggled: {
                                const a = Bluetooth.defaultAdapter;
                                if (a)
                                    a.enabled = !a.enabled;
                            }
                        }

                        Tile {
                            icon: "mic"
                            text: Tr.tr("Microphone")
                            on: !Audio.sourceMuted
                            onToggled: {
                                const audio = Audio.source?.audio;
                                if (audio)
                                    audio.muted = !audio.muted;
                            }
                        }

                        Tile {
                            icon: "notifications_off"
                            text: Tr.tr("Silent")
                            on: PersistentState.doNotDisturb
                            onToggled: PersistentState.doNotDisturb = !PersistentState.doNotDisturb
                        }

                        Tile {
                            icon: "gamepad"
                            text: Tr.tr("Game mode")
                            on: RuntimeState.gameMode
                            onToggled: RuntimeState.gameMode = !RuntimeState.gameMode
                        }

                        Tile {
                            icon: "vpn_key"
                            text: Tr.tr("VPN")
                            on: VPN.connected
                            onToggled: VPN.toggle()
                        }
                    }

                    // Volume
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: volRow.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainerHigh

                        RowLayout {
                            id: volRow

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.small

                            IconButton {
                                type: IconButton.Tonal
                                icon: Audio.muted ? "volume_off" : "volume_up"
                                onClicked: {
                                    const audio = Audio.sink?.audio;
                                    if (audio)
                                        audio.muted = !audio.muted;
                                }
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                implicitHeight: 24
                                value: Audio.volume
                                onMoved: Audio.setVolume(value)
                            }

                            StyledText {
                                Layout.preferredWidth: 38
                                horizontalAlignment: Text.AlignRight
                                text: `${Math.round(Audio.volume * 100)}%`
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.medium
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Notifications
                Item {
                    width: parent.parent.width
                    height: parent.height

                    ListView {
                        id: list

                        anchors.fill: parent
                        clip: true
                        spacing: Tokens.spacing.extraSmall
                        model: root.notifs
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: StyledRect {
                            id: card

                            required property var modelData

                            width: list.width
                            implicitHeight: cardRow.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.large
                            color: Colours.tPalette.m3surfaceContainerHigh

                            StateLayer {
                                onClicked: {
                                    const def = card.modelData.actions.find(a => a.identifier === "default") ?? (card.modelData.actions.length === 1 ? card.modelData.actions[0] : null);
                                    if (def)
                                        def.invoke();
                                }
                            }

                            RowLayout {
                                id: cardRow

                                anchors.fill: parent
                                anchors.margins: Tokens.padding.small
                                spacing: Tokens.spacing.small

                                // The app's icon, or the notification's picture
                                ClipRect {
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    radius: Tokens.rounding.medium
                                    color: Colours.palette.m3secondaryContainer

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: appImg.status !== Image.Ready
                                        text: "notifications"
                                        color: Colours.palette.m3onSecondaryContainer
                                        fontStyle: Tokens.font.icon.small
                                    }

                                    Image {
                                        id: appImg

                                        anchors.fill: parent
                                        anchors.margins: card.modelData.image ? 0 : 6
                                        source: card.modelData.image || (card.modelData.appIcon ? Quickshell.iconPath(card.modelData.appIcon, true) : "")
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize.width: 72
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: `${card.modelData.appName || Tr.tr("App")} · ${card.modelData.timeStr}`
                                        color: Colours.palette.m3primary
                                        font: Tokens.font.label.small
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: card.modelData.summary
                                        font: Tokens.font.body.small
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: card.modelData.body.replace(/<[^>]*>/g, "").replace(/\n/g, " ")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.label.small
                                        elide: Text.ElideRight
                                    }
                                }

                                IconButton {
                                    type: IconButton.Text
                                    icon: "close"
                                    onClicked: card.modelData.close()
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.notifs.length === 0
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "notifications_none"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.large
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Tr.tr("No notifications")
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }
    }

    component PaneButton: StyledRect {
        id: pb

        required property int index
        property string icon
        property string text
        readonly property bool chosen: root.pane === index

        implicitWidth: pbRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: pbRow.implicitHeight + Tokens.padding.small * 2
        radius: height / 2
        color: chosen ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

        StateLayer {
            color: pb.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: root.pane = pb.index
        }

        Row {
            id: pbRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.icon
                color: pb.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.text
                color: pb.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }
    }

    // A quick setting: its icon in a circle, its name and state
    component Tile: StyledRect {
        id: tile

        property string icon
        property string text
        property bool on

        signal toggled

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: tileRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.large
        color: on ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            color: tile.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            onClicked: tile.toggled()
        }

        RowLayout {
            id: tileRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: tile.on ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: tile.icon
                    color: tile.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                    fill: tile.on ? 1 : 0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: tile.text
                    color: tile.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.label.large
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.on ? Tr.tr("On") : Tr.tr("Off")
                    color: tile.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                    opacity: 0.8
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
