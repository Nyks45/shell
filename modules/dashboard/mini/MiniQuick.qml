pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus

// The island's page from a click on its pill: quick settings and notifications, side by side
// as two panes switched left and right (the header, the wheel or a swipe)
Item {
    id: root

    required property ScreenState screenState

    // 0 quick settings, 1 notifications; a page of its own shows one (fixedPane) without the
    // switch
    property int fixedPane: -1
    property int pane: fixedPane >= 0 ? fixedPane : 0

    // The island turns into the settings, at this page
    function openSettings(id: string): void {
        screenState.dashboardSettingsPage = id;
        screenState.dashboardRequest = "settings";
    }
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
                visible: root.fixedPane < 0
                index: 0
                icon: "tune"
                text: Tr.tr("Quick settings")
            }

            PaneButton {
                visible: root.fixedPane < 0
                index: 1
                icon: "notifications"
                text: root.notifs.length ? Tr.tr("Notifications (%1)").arg(root.notifs.length) : Tr.tr("Notifications")
            }

            // (a page of its own: just its title)
            StyledText {
                visible: root.fixedPane === 1
                leftPadding: Tokens.padding.small
                text: root.notifs.length ? Tr.tr("Notifications (%1)").arg(root.notifs.length) : Tr.tr("Notifications")
                font: Tokens.font.title.small
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

                // Quick settings: the network and Bluetooth as wide tiles (they open their lists), the switches as round buttons, then the power
                // mode and the volume (which opens the sound outputs)
                Item {
                    id: quickPane

                    width: parent.parent.width
                    height: parent.height

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Tokens.spacing.small
                        // (fades away while a list is open over it)
                        opacity: 1 - detail.t
                        visible: opacity > 0.01

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            WideTile {
                                id: netTile

                                readonly property bool wired: !!Nmcli.activeEthernet && !Nmcli.active

                                icon: wired ? "lan" : Nmcli.wifiEnabled ? "wifi" : "wifi_off"
                                text: wired ? Tr.tr("Ethernet") : Tr.tr("Wi-Fi")
                                sub: wired ? (Nmcli.activeEthernet.connection || Tr.tr("Connected")) : Nmcli.active?.ssid || (Nmcli.wifiEnabled ? Tr.tr("Not connected") : Tr.tr("Off"))
                                on: wired || Nmcli.wifiEnabled
                                expandable: true
                                onToggled: {
                                    if (!wired)
                                        Nmcli.toggleWifi();
                                }
                                onExpand: detail.open("network", netTile)
                            }

                            WideTile {
                                id: btTile

                                readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

                                icon: (Bluetooth.defaultAdapter?.enabled ?? false) ? "bluetooth" : "bluetooth_disabled"
                                text: Tr.tr("Bluetooth")
                                sub: !(Bluetooth.defaultAdapter?.enabled ?? false) ? Tr.tr("Off") : connected.length === 1 ? (connected[0].name || connected[0].deviceName) : connected.length > 1 ? Tr.tr("%1 devices").arg(connected.length) : Tr.tr("On")
                                on: Bluetooth.defaultAdapter?.enabled ?? false
                                expandable: true
                                onToggled: {
                                    const a = Bluetooth.defaultAdapter;
                                    if (a)
                                        a.enabled = !a.enabled;
                                }
                                onExpand: detail.open("bluetooth", btTile)
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            // Desktop mode (hyprflow): its icon shows which layout is on
                            RoundToggle {
                                icon: Hypr.desktopMode ? "desktop_windows" : "view_week"
                                text: Tr.tr("Desktop")
                                on: Hypr.desktopMode
                                onToggled: Hypr.toggleDesktopMode()
                            }

                            RoundToggle {
                                icon: Audio.sourceMuted ? "mic_off" : "mic"
                                text: Tr.tr("Mic")
                                on: !Audio.sourceMuted
                                onToggled: {
                                    const audio = Audio.source?.audio;
                                    if (audio)
                                        audio.muted = !audio.muted;
                                }
                            }

                            RoundToggle {
                                icon: "notifications_off"
                                text: Tr.tr("Silent")
                                on: PersistentState.doNotDisturb
                                onToggled: PersistentState.doNotDisturb = !PersistentState.doNotDisturb
                            }

                            RoundToggle {
                                icon: "sports_esports"
                                text: Tr.tr("Game")
                                on: RuntimeState.gameMode
                                onToggled: RuntimeState.gameMode = !RuntimeState.gameMode
                            }

                            RoundToggle {
                                icon: "vpn_key"
                                text: Tr.tr("VPN")
                                on: VPN.connected
                                onToggled: VPN.toggle()
                            }

                            RoundToggle {
                                icon: "smart_display"
                                text: Tr.tr("Live")
                                on: PersistentState.wallpaperPlaying
                                onToggled: PersistentState.wallpaperPlaying = !PersistentState.wallpaperPlaying
                            }

                            RoundToggle {
                                icon: "coffee"
                                text: Tr.tr("Awake")
                                on: RuntimeState.inhibitIdle
                                onToggled: RuntimeState.inhibitIdle = !RuntimeState.inhibitIdle
                            }

                            // The screen recorder: a click records the screen (with sound), a right
                            // click a region; while recording, a click stops it
                            RoundToggle {
                                icon: Recorder.running ? "stop_circle" : "screen_record"
                                text: Recorder.running ? Tr.tr("Stop") : Tr.tr("Record")
                                on: Recorder.running
                                onToggled: Recorder.running ? Recorder.stop() : Recorder.start(["-s"])
                                onAltToggled: {
                                    if (!Recorder.running)
                                        Recorder.start(["-sr"]);
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        // The power mode, then the volume
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            // The power mode: three fixed buttons, one highlight sliding between them
                            // (nothing changes size, so nothing shifts)
                            StyledRect {
                                id: modesBox

                                readonly property var modes: [
                                    {
                                        p: PowerProfile.PowerSaver,
                                        icon: "energy_savings_leaf"
                                    },
                                    {
                                        p: PowerProfile.Balanced,
                                        icon: "balance"
                                    },
                                    {
                                        p: PowerProfile.Performance,
                                        icon: "rocket_launch"
                                    }
                                ]
                                readonly property int chosen: Math.max(0, modes.findIndex(m => m.p === PowerProfiles.profile))
                                readonly property real cell: 38

                                implicitWidth: cell * modes.length + 6
                                implicitHeight: cell + 6
                                radius: height / 2
                                color: Colours.tPalette.m3surfaceContainerHigh

                                StyledRect {
                                    x: 3 + modesBox.chosen * modesBox.cell
                                    y: 3
                                    width: modesBox.cell
                                    height: modesBox.cell
                                    radius: height / 2
                                    color: Colours.palette.m3primary

                                    Behavior on x {
                                        Anim {
                                            type: Anim.DefaultSpatial
                                        }
                                    }
                                }

                                Row {
                                    x: 3
                                    y: 3

                                    Repeater {
                                        model: modesBox.modes

                                        Item {
                                            id: mode

                                            required property var modelData
                                            required property int index
                                            readonly property bool isChosen: modesBox.chosen === index

                                            width: modesBox.cell
                                            height: modesBox.cell

                                            StateLayer {
                                                radius: height / 2
                                                color: mode.isChosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                                onClicked: PowerProfiles.profile = mode.modelData.p
                                            }

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: mode.modelData.icon
                                                color: mode.isChosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                                fontStyle: Tokens.font.icon.small
                                                fill: mode.isChosen ? 1 : 0

                                                Behavior on color {
                                                    CAnim {}
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // The volume: the speaker icon (a click mutes), a smooth bar with a knob
                            // (drag or wheel), and the arrow to the outputs. No text.
                            RowLayout {
                                id: vol

                                readonly property real level: Audio.muted ? 0 : Math.max(0, Math.min(1, Audio.volume))

                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                StyledRect {
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    radius: 19
                                    color: Audio.muted ? Colours.tPalette.m3surfaceContainerHigh : Colours.palette.m3primaryContainer

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    StateLayer {
                                        radius: 19
                                        onClicked: {
                                            const audio = Audio.sink?.audio;
                                            if (audio)
                                                audio.muted = !audio.muted;
                                        }
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: Audio.muted ? "volume_off" : vol.level < 0.34 ? "volume_mute" : vol.level < 0.67 ? "volume_down" : "volume_up"
                                        color: Audio.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onPrimaryContainer
                                        fontStyle: Tokens.font.icon.small
                                        fill: 1
                                    }
                                }

                                Item {
                                    id: track

                                    Layout.fillWidth: true
                                    implicitHeight: 38

                                    // The groove
                                    StyledRect {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 12
                                        radius: 6
                                        color: Colours.tPalette.m3surfaceContainerHigh
                                    }

                                    // The fill, a soft gradient
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(height, knob.x + knob.width / 2)
                                        height: 12
                                        radius: 6
                                        opacity: Audio.muted ? 0.35 : 1
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal

                                            GradientStop {
                                                position: 0
                                                color: Colours.palette.m3primary
                                            }
                                            GradientStop {
                                                position: 1
                                                color: Colours.palette.m3tertiary
                                            }
                                        }
                                    }

                                    // The knob: grows while held
                                    StyledRect {
                                        id: knob

                                        x: (track.width - width) * vol.level
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: volArea.pressed ? 26 : volArea.containsMouse ? 22 : 18
                                        height: width
                                        radius: width / 2
                                        color: Colours.palette.m3onSurface
                                        border.width: 3
                                        border.color: Colours.palette.m3primary

                                        Behavior on x {
                                            enabled: !volArea.pressed

                                            Anim {}
                                        }

                                        Behavior on width {
                                            Anim {}
                                        }
                                    }

                                    MouseArea {
                                        id: volArea

                                        function set(x: real): void {
                                            Audio.setVolume(Math.max(0, Math.min(1, x / width)));
                                        }

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: event => set(event.x)
                                        onPositionChanged: event => {
                                            if (pressed)
                                                set(event.x);
                                        }
                                        onWheel: event => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
                                    }
                                }

                                IconButton {
                                    type: IconButton.Text
                                    icon: "chevron_right"
                                    onClicked: detail.open("audio", track)
                                }
                            }
                        }
                    }

                    // A tile's list (Wi-Fi networks, Bluetooth devices, sound outputs: the bar's own
                    // popouts): it grows out of the tile into the whole pane, and shrinks back
                    // into it, with the bar popouts' motion
                    Item {
                        id: detail

                        property string kind
                        property Item from
                        property rect start
                        // 0 at the tile .. 1 the whole pane
                        property real t: 0
                        readonly property rect full: Qt.rect(0, 0, quickPane.width, quickPane.height)

                        function open(k: string, item: Item): void {
                            const p = item.mapToItem(quickPane, 0, 0);
                            start = Qt.rect(p.x, p.y, item.width, item.height);
                            from = item;
                            kind = k;
                            t = 1;
                        }

                        function close(): void {
                            t = 0;
                        }

                        Shortcut {
                            sequence: "Escape"
                            enabled: detail.t > 0.5
                            onActivated: detail.close()
                        }

                        visible: t > 0.001
                        z: 10
                        x: start.x + (full.x - start.x) * t
                        y: start.y + (full.y - start.y) * t
                        width: start.width + (full.width - start.width) * t
                        height: start.height + (full.height - start.height) * t

                        Behavior on t {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }

                        // Leaving the pane closes it
                        Connections {
                            function onPaneChanged(): void {
                                detail.t = 0;
                            }

                            target: root
                        }

                        // See-through: the island's own blurred glass shows, with a soft rim (the
                        // tiles fade out under it)
                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.large + (Tokens.rounding.extraLarge - Tokens.rounding.large) * detail.t
                            color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.25)
                            border.width: 1
                            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                        }

                        QuickDetail {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            clip: true
                            kind: detail.kind || "network"
                            opacity: Math.max(0, (detail.t - 0.5) * 2)
                            onCloseRequested: detail.close()
                            onSettingsRequested: id => root.openSettings(id)
                        }
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
                        // Scrolls whole cards
                        snapMode: ListView.SnapToItem
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: StyledRect {
                            id: card

                            required property var modelData

                            width: list.width
                            // Fixed: three always fit whole in the pane
                            implicitHeight: Math.floor((list.height - list.spacing * 2) / 3)
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
                                    implicitWidth: 34
                                    implicitHeight: 34
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
                                        fillMode: card.modelData.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                        asynchronous: true
                                        sourceSize.width: 72
                                    }
                                }

                                // Two lines: what it says, then the app, when and the rest
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: card.modelData.summary
                                        font: Tokens.font.body.small
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: {
                                            const body = card.modelData.body.replace(/<[^>]*>/g, "").replace(/\n/g, " ");
                                            return `${card.modelData.appName || Tr.tr("App")} · ${card.modelData.timeStr}${body ? " — " + body : ""}`;
                                        }
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

    // A wide tile: its icon in a circle, its name and what it's on (the network, the device)
    component WideTile: StyledRect {
        id: wt

        property string icon
        property string text
        property string sub
        property bool on
        // An arrow on its right opens its list
        property bool expandable

        signal toggled
        signal expand

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        // The ones with an arrow get a little more of the row
        Layout.horizontalStretchFactor: expandable ? 6 : 4
        implicitHeight: 58
        radius: Tokens.rounding.extraLarge
        color: on ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            color: wt.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            onClicked: wt.toggled()
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            anchors.rightMargin: wt.expandable ? 2 : Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: wt.on ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: wt.icon
                    color: wt.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                    fill: wt.on ? 1 : 0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: wt.text
                    color: wt.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.label.large
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: wt.sub
                    color: wt.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                    opacity: 0.8
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: wt.expandable
                type: IconButton.Text
                icon: "chevron_right"
                inactiveOnColour: wt.on ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                onClicked: wt.expand()
            }
        }
    }

    // A round switch with its name under it
    component RoundToggle: ColumnLayout {
        id: rt

        property string icon
        property string text
        property bool on

        signal toggled
        signal altToggled

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.maximumWidth: 10000
        spacing: 2

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 48
            implicitHeight: 42
            radius: rt.on ? Tokens.rounding.large : 21
            color: rt.on ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

            Behavior on radius {
                Anim {}
            }

            Behavior on color {
                CAnim {}
            }

            StateLayer {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                color: rt.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                onClicked: event => event.button === Qt.RightButton ? rt.altToggled() : rt.toggled()
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: rt.icon
                color: rt.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
                fill: rt.on ? 1 : 0
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: rt.text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
