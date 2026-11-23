pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    property bool active: true
    property bool compact: false
    property bool showCloseButton: true
    property string tab: "outputs"
    property bool _refOpen: false

    signal closeRequested
    signal settingsRequested(id: string)

    readonly property real maxVol: Math.max(1, GlobalConfig.services.maxVolume)
    readonly property bool overAmp: maxVol > 1.001

    readonly property var tabSpecs: [
        {
            key: "playback",
            label: Audio.streams.length > 0 ? Tr.tr("Playback (%1)").arg(Audio.streams.length) : Tr.tr("Playback")
        },
        {
            key: "recording",
            label: Audio.recordingStreams.length > 0 ? Tr.tr("Recording (%1)").arg(Audio.recordingStreams.length) : Tr.tr("Recording")
        },
        {
            key: "outputs",
            label: Tr.tr("Outputs")
        },
        {
            key: "inputs",
            label: Tr.tr("Inputs")
        },
        {
            key: "cards",
            label: Tr.tr("Cards")
        }
    ]

    function syncRef(): void {
        const want = root.active && root.visible;
        if (want === root._refOpen)
            return;
        root._refOpen = want;
        if (want)
            Audio.openMixerRef();
        else
            Audio.closeMixerRef();
    }

    function selectTab(nextTab: string): void {
        root.tab = nextTab;
        Audio.lastMixerTab = nextTab;
    }

    function appIconName(node: PwNode): string {
        const props = node?.properties ?? {};
        const direct = String(props["application.icon-name"] ?? props["media.icon-name"] ?? "");
        if (direct)
            return direct;
        const candidates = [props["application.process.binary"], props["application.name"], node?.name].filter(s => !!s);
        for (const c of candidates) {
            const entry = DesktopEntries.heuristicLookup(String(c)) ?? DesktopEntries.byId(String(c));
            if (entry?.icon)
                return entry.icon;
        }
        return "";
    }

    onActiveChanged: syncRef()
    onVisibleChanged: syncRef()
    Component.onCompleted: {
        tab = Audio.lastMixerTab || (Audio.streams.length > 0 ? "playback" : "outputs");
        syncRef();
    }
    Component.onDestruction: {
        if (root._refOpen) {
            root._refOpen = false;
            Audio.closeMixerRef();
        }
    }

    AudioPeakMonitor {
        id: peakMonitor

        active: root.active && root.visible && root.opacity > 0.1
        targets: {
            const list = [];
            if (root.tab === "playback") {
                for (const n of Audio.streams) {
                    const s = Audio.nodeKey(n);
                    if (s)
                        list.push({
                            serial: s,
                            captureSink: false
                        });
                }
            } else if (root.tab === "recording") {
                for (const n of Audio.recordingStreams) {
                    const s = Audio.nodeKey(n);
                    if (s)
                        list.push({
                            serial: s,
                            captureSink: false
                        });
                }
            } else if (root.tab === "outputs") {
                for (const n of Audio.sinks) {
                    const s = Audio.nodeKey(n);
                    if (s)
                        list.push({
                            serial: s,
                            captureSink: true
                        });
                }
            } else if (root.tab === "inputs") {
                for (const n of Audio.sources) {
                    const s = Audio.nodeKey(n);
                    if (s)
                        list.push({
                            serial: s,
                            captureSink: false
                        });
                }
                if (Audio.showMonitors) {
                    for (const m of Audio.monitorSources) {
                        if (m.sinkSerial)
                            list.push({
                                serial: String(m.sinkSerial),
                                captureSink: true
                            });
                    }
                }
            }
            return list;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: Colours.palette.m3primary

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "tune"
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.small
                    fill: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Sound")
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (monitorsBtn.hovered)
                            return Audio.showMonitors ? Tr.tr("Hide virtual output monitors") : Tr.tr("Show virtual output monitors");
                        if (boostBtn.hovered)
                            return root.overAmp ? Tr.tr("Max volume 150% — click for 100%") : Tr.tr("Allow volume boost up to 150%");
                        if (beepBtn.hovered)
                            return Audio.beepOnVolumeChange ? Tr.tr("Volume feedback sound: On") : Tr.tr("Volume feedback sound: Off");
                        if (settingsBtn.hovered)
                            return Tr.tr("Open full Sound settings");
                        if (closeBtn.hovered)
                            return Tr.tr("Close mixer");
                        return Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Tr.tr("No output device");
                    }
                    color: (monitorsBtn.hovered || boostBtn.hovered || beepBtn.hovered || settingsBtn.hovered || closeBtn.hovered) ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            // Show virtual output loopback monitor sources (Inputs tab)
            IconTextButton {
                id: monitorsBtn

                visible: root.tab === "inputs"
                type: Audio.showMonitors ? TextButton.Filled : TextButton.Tonal
                isToggle: true
                followChecked: true
                checked: Audio.showMonitors
                icon: "hearing"
                text: Tr.tr("Monitors")
                horizontalPadding: Tokens.padding.small
                verticalPadding: Tokens.padding.extraSmall
                onClicked: Audio.showMonitors = !Audio.showMonitors
            }

            // Over-amplification (100% <-> 150%) toggle
            TextButton {
                id: boostBtn

                text: root.overAmp ? Tr.tr("150%") : Tr.tr("100%")
                isToggle: true
                followChecked: true
                checked: root.overAmp
                type: root.overAmp ? TextButton.Filled : TextButton.Tonal
                horizontalPadding: Tokens.padding.small
                verticalPadding: Tokens.padding.extraSmall
                onClicked: GlobalConfig.services.maxVolume = root.overAmp ? 1.0 : 1.5
            }

            // Play beep on volume change toggle
            IconButton {
                id: beepBtn

                type: Audio.beepOnVolumeChange ? IconButton.Filled : IconButton.Tonal
                isToggle: true
                followChecked: true
                checked: Audio.beepOnVolumeChange
                icon: Audio.beepOnVolumeChange ? "notifications_active" : "notifications_off"
                font: Tokens.font.icon.small
                implicitHeight: 32
                onClicked: Audio.beepOnVolumeChange = !Audio.beepOnVolumeChange
            }

            // Open full Sound page in Settings
            IconButton {
                id: settingsBtn

                type: IconButton.Text
                icon: "open_in_new"
                font: Tokens.font.icon.small
                implicitHeight: 32
                onClicked: root.settingsRequested("audio")
            }

            IconButton {
                id: closeBtn

                visible: root.showCloseButton
                type: IconButton.Tonal
                icon: "close"
                font: Tokens.font.icon.small
                implicitHeight: 32
                onClicked: root.closeRequested()
            }
        }

        // 5-Tab segmented bar
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: height / 2
            color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.55)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 2

                Repeater {
                    model: root.tabSpecs

                    StyledRect {
                        id: tabBtn

                        required property var modelData
                        readonly property bool isSelected: root.tab === modelData.key

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: tabLabel.implicitWidth + Tokens.padding.small * 2
                        Layout.preferredWidth: tabLabel.implicitWidth + Tokens.padding.medium * 2
                        radius: height / 2
                        color: isSelected ? Colours.palette.m3primary : "transparent"

                        Behavior on color {
                            CAnim {}
                        }

                        StateLayer {
                            radius: parent.radius
                            color: tabBtn.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            onClicked: root.selectTab(tabBtn.modelData.key)
                        }

                        StyledText {
                            id: tabLabel

                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - Tokens.padding.small)
                            horizontalAlignment: Text.AlignHCenter
                            text: tabBtn.modelData.label
                            color: tabBtn.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Scrollable tab content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: mixerList

                anchors.fill: parent
                clip: true
                spacing: Tokens.spacing.small
                boundsBehavior: Flickable.StopAtBounds
                model: {
                    if (root.tab === "playback")
                        return Audio.streams.map(n => ({
                                    kind: "playback",
                                    node: n,
                                    card: null,
                                    monitor: null
                                }));
                    if (root.tab === "recording")
                        return Audio.recordingStreams.map(n => ({
                                    kind: "recording",
                                    node: n,
                                    card: null,
                                    monitor: null
                                }));
                    if (root.tab === "outputs")
                        return Audio.sinks.map(n => ({
                                    kind: "output",
                                    node: n,
                                    card: null,
                                    monitor: null
                                }));
                    if (root.tab === "inputs") {
                        const out = Audio.sources.map(n => ({
                                    kind: "input",
                                    node: n,
                                    card: null,
                                    monitor: null
                                }));
                        if (Audio.showMonitors) {
                            for (const m of Audio.monitorSources) {
                                out.push({
                                    kind: "monitor",
                                    node: null,
                                    card: null,
                                    monitor: m
                                });
                            }
                        }
                        return out;
                    }
                    return (Audio.allCards ?? []).map(c => ({
                                kind: "card",
                                node: null,
                                card: c,
                                monitor: null
                            }));
                }

                delegate: Item {
                    id: rowWrap

                    required property var modelData
                    readonly property string kind: modelData.kind

                    width: mixerList.width
                    implicitHeight: cardLoader.implicitHeight

                    Loader {
                        id: cardLoader

                        width: parent.width
                        sourceComponent: rowWrap.kind === "card" ? cardConfigComp : rowWrap.kind === "monitor" ? monitorCardComp : nodeCardComp

                        onLoaded: {
                            if (rowWrap.kind === "card")
                                item.card = rowWrap.modelData.card; // qmllint disable missing-property
                            else if (rowWrap.kind === "monitor")
                                item.mon = rowWrap.modelData.monitor; // qmllint disable missing-property
                            else {
                                item.kind = rowWrap.kind; // qmllint disable missing-property
                                item.node = rowWrap.modelData.node; // qmllint disable missing-property
                            }
                        }

                        Binding {
                            target: cardLoader.item
                            property: rowWrap.kind === "card" ? "card" : rowWrap.kind === "monitor" ? "mon" : "node"
                            value: rowWrap.kind === "card" ? rowWrap.modelData.card : rowWrap.kind === "monitor" ? rowWrap.modelData.monitor : rowWrap.modelData.node
                            when: !!cardLoader.item
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                width: parent.width - Tokens.padding.large * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: mixerList.count === 0
                text: {
                    switch (root.tab) {
                    case "playback":
                        return Tr.tr("No apps are currently playing audio");
                    case "recording":
                        return Tr.tr("No apps are currently recording audio");
                    case "outputs":
                        return Tr.tr("No output devices found");
                    case "inputs":
                        return Tr.tr("No input devices found");
                    default:
                        return Tr.tr("No sound cards detected");
                    }
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }
    }

    // Smooth wheel-safe slider + live 25 Hz VU meter bar + % / dB readout
    component LevelTrack: Item {
        id: lt

        property real value: 0
        property real peak: 0
        property real maxValue: root.maxVol
        property bool muted: false
        property bool showPeak: true

        signal moved(real newValue)
        signal committed

        readonly property real frac: Math.max(0, Math.min(1, maxValue > 0 ? value / maxValue : 0))
        readonly property real unityFrac: maxValue > 1.001 ? 1.0 / maxValue : 1.0

        implicitHeight: ltLayout.implicitHeight

        ColumnLayout {
            id: ltLayout

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Item {
                    id: grooveBox

                    Layout.fillWidth: true
                    implicitHeight: 24

                    // Groove
                    StyledRect {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        radius: 4
                        color: Qt.alpha(Colours.tPalette.m3surfaceContainerHighest, 0.7)
                    }

                    // Active fill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(height, thumb.x + thumb.width / 2)
                        height: 8
                        radius: 4
                        opacity: lt.muted ? 0.35 : 1
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

                    // 100% unity notch when over-amplification is active
                    Rectangle {
                        visible: lt.maxValue > 1.001
                        x: (grooveBox.width - thumb.width) * lt.unityFrac + thumb.width / 2 - 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 14
                        radius: 1
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.65)
                    }

                    // Thumb
                    StyledRect {
                        id: thumb

                        x: (grooveBox.width - width) * lt.frac
                        anchors.verticalCenter: parent.verticalCenter
                        width: dragArea.pressed ? 18 : dragArea.containsMouse ? 16 : 14
                        height: width
                        radius: width / 2
                        color: Colours.palette.m3onSurface
                        border.width: 2
                        border.color: Colours.palette.m3primary

                        Behavior on width {
                            Anim {}
                        }
                    }

                    // Drag / click ONLY (no wheel capture so scrolling ListView never edits volumes)
                    MouseArea {
                        id: dragArea

                        function applyX(px: real): void {
                            if (width <= 0)
                                return;
                            let target = Math.max(0, Math.min(1, px / width)) * lt.maxValue;
                            if (lt.maxValue > 1.001 && Math.abs(target - 1.0) <= 0.025)
                                target = 1.0;
                            lt.moved(target);
                        }

                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: event => applyX(event.x)
                        onPositionChanged: event => {
                            if (pressed)
                                applyX(event.x);
                        }
                        onReleased: lt.committed()
                    }
                }

                StyledText {
                    Layout.minimumWidth: root.compact ? 88 : 96
                    horizontalAlignment: Text.AlignRight
                    text: lt.muted ? Tr.tr("Muted") : `${Math.round(lt.value * 100)}% · ${Audio.volumeDb(lt.value)}`
                    color: lt.muted ? Colours.palette.m3outline : lt.value > 1.001 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }

            // Live 25 Hz peak VU meter
            StyledRect {
                visible: lt.showPeak
                Layout.fillWidth: true
                Layout.rightMargin: (root.compact ? 88 : 96) + Tokens.spacing.small
                implicitHeight: 4
                radius: 2
                color: Qt.alpha(Colours.tPalette.m3surfaceContainerHighest, 0.45)

                StyledRect {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(1, lt.muted ? 0 : lt.peak)) * parent.width
                    radius: parent.radius
                    color: lt.peak > 0.88 ? Colours.palette.m3error : Colours.palette.m3primary

                    Behavior on width {
                        NumberAnimation {
                            duration: 40
                        }
                    }
                }
            }
        }
    }

    // Stream / Device Card (Playback, Recording, Outputs, Inputs)
    Component {
        id: nodeCardComp

        StyledRect {
            id: card

            property string kind: "output"
            property PwNode node: null
            property bool latencyOpen: false

            readonly property bool isStreamCard: kind === "playback" || kind === "recording"
            readonly property bool isOutputKind: kind === "playback" || kind === "output"
            readonly property string serial: Audio.nodeKey(node)
            readonly property real peak: Number(peakMonitor.peaks[serial] ?? 0)
            readonly property bool muted: !!(node?.audio?.muted)
            readonly property real volume: Number(node?.audio?.volume ?? 0)
            readonly property var channels: Array.from(node?.audio?.channels ?? [])
            readonly property var channelVolumes: Array.from(node?.audio?.volumes ?? [])
            readonly property bool canLockChannels: channels.length > 1
            readonly property bool locked: Audio.isChannelLocked(node)
            readonly property var meta: kind === "output" ? (Audio.sinkMeta[node?.name ?? ""] ?? null) : kind === "input" ? (Audio.sourceMeta[node?.name ?? ""] ?? null) : null
            readonly property var ports: meta?.ports ?? []
            readonly property string activePort: String(meta?.activePort ?? "")
            readonly property string cardName: String(meta?.cardName ?? "")
            readonly property int latencyOffsetMs: Number(meta?.latencyOffsetMs ?? 0)
            readonly property bool isDefault: (kind === "output" && Audio.sink === node) || (kind === "input" && Audio.source === node)
            readonly property string iconName: card.isStreamCard ? root.appIconName(card.node) : ""

            readonly property var targetNodes: kind === "playback" ? Audio.sinks : Audio.sources
            readonly property PwNode linkedDevice: {
                if (!card.isStreamCard || !card.node)
                    return null;
                const g = linkTracker.linkGroups.find(lg => card.isOutputKind ? lg.source === card.node : lg.target === card.node);
                return g ? (card.isOutputKind ? g.target : g.source) : null;
            }
            readonly property string activeRouteValue: card.isStreamCard ? Audio.streamRouteName(card.kind, card.node, linkedDevice) : ""
            readonly property var routeChoices: {
                if (!card.isStreamCard)
                    return [];
                const out = targetNodes.map(d => ({
                            value: String(d.name ?? ""),
                            label: Audio.friendlyDeviceName(d),
                            isMonitor: false
                        }));
                if (card.kind === "recording") {
                    for (const m of Audio.monitorSources) {
                        out.push({
                            value: m.name,
                            label: Tr.tr("Monitor: %1").arg(m.friendlyLabel || m.description.replace(/^Monitor of\s+/i, "")),
                            isMonitor: true
                        });
                    }
                }
                return out;
            }

            implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.52)

            PwNodeLinkTracker {
                id: linkTracker

                node: card.isStreamCard ? card.node : null
            }

            ColumnLayout {
                id: col

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                // Row 1: Icon + title + primary action controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Item {
                        implicitWidth: 24
                        implicitHeight: 24

                        ThemedIcon {
                            id: appIconImg

                            anchors.fill: parent
                            visible: status === Image.Ready && String(source).length > 0
                            source: card.iconName ? Quickshell.iconPath(card.iconName, true) : ""
                            implicitSize: 22
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !appIconImg.visible
                            text: card.isOutputKind ? (card.isStreamCard ? "music_note" : "speaker") : "mic"
                            color: card.isDefault ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                            fill: card.isDefault ? 1 : 0
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: card.isStreamCard ? Audio.getStreamName(card.node) : Audio.friendlyDeviceName(card.node)
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            readonly property string media: String(card.node?.properties?.["media.name"] ?? "")
                            readonly property string app: card.isStreamCard ? Audio.getStreamName(card.node) : ""

                            Layout.fillWidth: true
                            visible: card.isStreamCard && !!media && media !== app
                            text: media
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    // Playback / Recording: Device selector dropdown
                    IconTextButton {
                        id: routeBtn

                        visible: card.isStreamCard && card.routeChoices.length > 0
                        type: TextButton.Tonal
                        icon: card.activeRouteValue.endsWith(".monitor") ? "hearing" : (card.isOutputKind ? "speaker" : "mic")
                        label.elide: Text.ElideRight
                        label.Layout.maximumWidth: root.compact ? 168 : 210
                        text: {
                            const match = card.routeChoices.find(c => c.value === card.activeRouteValue);
                            if (match)
                                return match.label;
                            if (card.activeRouteValue.endsWith(".monitor")) {
                                const base = card.activeRouteValue.replace(/\.monitor$/, "");
                                const sink = Audio.sinks.find(s => s.name === base);
                                return sink ? Tr.tr("Monitor: %1").arg(Audio.friendlyDeviceName(sink)) : Tr.tr("Monitor");
                            }
                            return Tr.tr("Default");
                        }
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: routeMenu.expanded = !routeMenu.expanded

                        Menu {
                            id: routeMenu

                            attachTo: routeBtn
                            items: routeItems.instances
                            onItemSelected: item => {
                                const targetName = String(item.value ?? "");
                                if (!card.node || !targetName)
                                    return;
                                if (card.kind === "playback") {
                                    const s = Audio.sinks.find(x => x.name === targetName);
                                    if (s)
                                        Audio.moveStreamToSink(card.node, s);
                                } else {
                                    Audio.moveRecordingToSourceName(card.node, targetName);
                                }
                            }

                            Binding {
                                target: routeMenu
                                property: "active"
                                value: routeItems.instances.find(i => i.value === card.activeRouteValue) ?? null
                            }

                            Variants {
                                id: routeItems

                                model: card.routeChoices

                                MenuItem {
                                    required property var modelData

                                    text: modelData.label
                                    value: modelData.value
                                    icon: modelData.isMonitor ? "hearing" : (card.isOutputKind ? "speaker" : "mic")
                                }
                            }
                        }
                    }

                    // Outputs / Inputs: Windows-style Set as Default toggle button
                    IconTextButton {
                        visible: !card.isStreamCard
                        isToggle: true
                        followChecked: true
                        checked: card.isDefault
                        type: card.isDefault ? TextButton.Filled : TextButton.Tonal
                        icon: card.isDefault ? "check" : "star_outline"
                        text: card.isDefault ? Tr.tr("Default") : Tr.tr("Set default")
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: {
                            if (!card.node)
                                return;
                            if (card.kind === "output")
                                Audio.setAudioSink(card.node);
                            else
                                Audio.setAudioSource(card.node);
                        }
                    }

                    // Lock/unlock stereo/surround channels
                    IconButton {
                        visible: card.canLockChannels
                        type: card.locked ? IconButton.Tonal : IconButton.Filled
                        isToggle: true
                        followChecked: true
                        checked: !card.locked
                        icon: card.locked ? "lock" : "lock_open"
                        font: Tokens.font.icon.small
                        implicitHeight: 30
                        onClicked: Audio.setChannelLocked(card.node, !card.locked)
                    }
                }

                // Master volume row (locked or single-channel)
                RowLayout {
                    visible: card.locked || !card.canLockChannels
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconButton {
                        type: card.muted ? IconButton.Filled : IconButton.Tonal
                        isToggle: true
                        followChecked: true
                        checked: card.muted
                        icon: card.isOutputKind ? Icons.getVolumeIcon(card.volume, card.muted) : Icons.getMicVolumeIcon(card.volume, card.muted)
                        font: Tokens.font.icon.small
                        implicitHeight: 30
                        onClicked: Audio.setStreamMuted(card.node, !card.muted)
                    }

                    LevelTrack {
                        Layout.fillWidth: true
                        value: card.volume
                        peak: card.peak
                        muted: card.muted
                        onMoved: v => Audio.setNodeVolume(card.node, v)
                        onCommitted: Audio.playVolumeBeep()
                    }
                }

                // Per-channel unlocked rows
                ColumnLayout {
                    visible: !card.locked && card.canLockChannels
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        IconButton {
                            type: card.muted ? IconButton.Filled : IconButton.Tonal
                            isToggle: true
                            followChecked: true
                            checked: card.muted
                            icon: card.isOutputKind ? Icons.getVolumeIcon(card.volume, card.muted) : Icons.getMicVolumeIcon(card.volume, card.muted)
                            font: Tokens.font.icon.small
                            implicitHeight: 28
                            onClicked: Audio.setStreamMuted(card.node, !card.muted)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("Channels unlocked (%1)").arg(card.channels.length)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }

                    Repeater {
                        model: (!card.locked && card.canLockChannels) ? card.channels.length : 0

                        ColumnLayout {
                            id: chRow

                            required property int index
                            readonly property real chVol: Number(card.channelVolumes[index] ?? card.volume)

                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: Audio.channelName(card.channels[chRow.index])
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }

                            LevelTrack {
                                Layout.fillWidth: true
                                value: chRow.chVol
                                peak: card.peak
                                muted: card.muted
                                showPeak: chRow.index === card.channels.length - 1
                                onMoved: v => Audio.setNodeChannelVolume(card.node, chRow.index, v)
                                onCommitted: Audio.playVolumeBeep()
                            }
                        }
                    }
                }

                // Device Port & Latency offset bar (Outputs / Inputs with hardware metadata)
                RowLayout {
                    visible: !card.isStreamCard && (card.ports.length > 1 || (card.cardName !== "" && card.activePort !== ""))
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconTextButton {
                        id: portBtn

                        visible: card.ports.length > 1
                        type: TextButton.Tonal
                        icon: "cable"
                        label.elide: Text.ElideRight
                        label.Layout.maximumWidth: root.compact ? 210 : 280
                        text: {
                            const cur = card.ports.find(p => p.name === card.activePort);
                            return cur ? cur.description : (card.activePort || Tr.tr("Port"));
                        }
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: portMenu.expanded = !portMenu.expanded

                        Menu {
                            id: portMenu

                            attachTo: portBtn
                            items: portItems.instances
                            onItemSelected: item => {
                                const pname = String(item.value ?? "");
                                if (!card.node?.name || !pname)
                                    return;
                                if (card.kind === "output")
                                    Audio.setSinkPort(card.node.name, pname);
                                else
                                    Audio.setSourcePort(card.node.name, pname);
                            }

                            Binding {
                                target: portMenu
                                property: "active"
                                value: portItems.instances.find(i => i.value === card.activePort) ?? null
                            }

                            Variants {
                                id: portItems

                                model: card.ports

                                MenuItem {
                                    required property var modelData

                                    text: modelData.availability === "not available" ? Tr.tr("%1 (unplugged)").arg(modelData.description) : modelData.description
                                    value: modelData.name
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconTextButton {
                        visible: card.cardName !== "" && card.activePort !== ""
                        isToggle: true
                        followChecked: true
                        checked: card.latencyOpen
                        type: card.latencyOpen ? TextButton.Filled : TextButton.Tonal
                        icon: "schedule"
                        text: card.latencyOffsetMs !== 0 ? Tr.tr("Latency %1 ms").arg(card.latencyOffsetMs) : Tr.tr("Latency")
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: card.latencyOpen = !card.latencyOpen
                    }
                }

                // Expandable Latency offset stepper (-500 .. +2000 ms)
                RowLayout {
                    visible: card.latencyOpen && card.cardName !== "" && card.activePort !== ""
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Port latency offset")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    TextButton {
                        visible: card.latencyOffsetMs !== 0
                        type: TextButton.Text
                        text: Tr.tr("Reset")
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: Audio.setPortLatencyOffset(card.cardName, card.activePort, 0)
                    }

                    IconButton {
                        type: IconButton.Tonal
                        icon: "remove"
                        font: Tokens.font.icon.small
                        implicitHeight: 28
                        disabled: card.latencyOffsetMs <= -500
                        onClicked: Audio.setPortLatencyOffset(card.cardName, card.activePort, Math.max(-500, card.latencyOffsetMs - 5))
                    }

                    StyledText {
                        Layout.minimumWidth: 60
                        horizontalAlignment: Text.AlignHCenter
                        text: `${card.latencyOffsetMs} ms`
                        font: Tokens.font.body.small
                    }

                    IconButton {
                        type: IconButton.Tonal
                        icon: "add"
                        font: Tokens.font.icon.small
                        implicitHeight: 28
                        disabled: card.latencyOffsetMs >= 2000
                        onClicked: Audio.setPortLatencyOffset(card.cardName, card.activePort, Math.min(2000, card.latencyOffsetMs + 5))
                    }
                }
            }
        }
    }

    // Monitor source card (shown on Inputs tab when Show monitors is enabled)
    Component {
        id: monitorCardComp

        StyledRect {
            id: monCard

            property var mon: null
            readonly property string sname: String(mon?.name ?? "")
            readonly property bool muted: !!(mon?.mute)
            readonly property real volume: Number(mon?.volume ?? 1)
            readonly property real peak: Number(peakMonitor.peaks[String(mon?.sinkSerial ?? "")] ?? 0)

            implicitHeight: monCol.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.42)

            ColumnLayout {
                id: monCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "hearing"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: monCard.mon?.friendlyLabel ? Tr.tr("Monitor of %1").arg(monCard.mon.friendlyLabel) : (monCard.mon?.description || monCard.sname)
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        implicitWidth: monTag.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: 22
                        radius: height / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        StyledText {
                            id: monTag

                            anchors.centerIn: parent
                            text: Tr.tr("Monitor")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconButton {
                        type: monCard.muted ? IconButton.Filled : IconButton.Tonal
                        isToggle: true
                        followChecked: true
                        checked: monCard.muted
                        icon: Icons.getMicVolumeIcon(monCard.volume, monCard.muted)
                        font: Tokens.font.icon.small
                        implicitHeight: 30
                        onClicked: Audio.setMonitorMuted(monCard.sname, !monCard.muted)
                    }

                    LevelTrack {
                        Layout.fillWidth: true
                        value: monCard.volume
                        peak: monCard.peak
                        muted: monCard.muted
                        onMoved: v => Audio.setMonitorVolume(monCard.sname, v)
                        onCommitted: Audio.playVolumeBeep()
                    }
                }
            }
        }
    }

    // Hardware Card Configuration tab card (Profile/Codec selector + port latency)
    Component {
        id: cardConfigComp

        StyledRect {
            id: hwCard

            property var card: null
            readonly property string cardName: String(card?.name ?? "")
            readonly property string activeProfile: String(card?.activeProfile ?? "")
            readonly property var profiles: card?.profiles ?? []
            readonly property var ports: (card?.ports ?? []).filter(p => p.availability !== "not available")

            implicitHeight: hwCol.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.52)

            ColumnLayout {
                id: hwCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "settings_input_component"
                        color: hwCard.activeProfile === "off" ? Colours.palette.m3outline : Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: hwCard.card?.label || hwCard.cardName
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const p = hwCard.profiles.find(x => x.name === hwCard.activeProfile);
                                return p ? p.description : hwCard.activeProfile;
                            }
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconTextButton {
                        id: profBtn

                        type: hwCard.activeProfile === "off" ? TextButton.Tonal : TextButton.Filled
                        icon: "tune"
                        label.elide: Text.ElideRight
                        label.Layout.maximumWidth: root.compact ? 190 : 230
                        text: {
                            const p = hwCard.profiles.find(x => x.name === hwCard.activeProfile);
                            return p ? p.description : (hwCard.activeProfile || Tr.tr("Profile"));
                        }
                        horizontalPadding: Tokens.padding.small
                        verticalPadding: Tokens.padding.extraSmall
                        onClicked: profMenu.expanded = !profMenu.expanded

                        Menu {
                            id: profMenu

                            attachTo: profBtn
                            items: profItems.instances
                            onItemSelected: item => Audio.setCardProfile(hwCard.cardName, String(item.value ?? ""))

                            Binding {
                                target: profMenu
                                property: "active"
                                value: profItems.instances.find(i => i.value === hwCard.activeProfile) ?? null
                            }

                            Variants {
                                id: profItems

                                model: hwCard.profiles

                                MenuItem {
                                    required property var modelData

                                    text: modelData.available ? modelData.description : Tr.tr("%1 (unplugged)").arg(modelData.description)
                                    value: modelData.name
                                }
                            }
                        }
                    }
                }

                // Active / plugged ports latency offset rows
                Repeater {
                    model: hwCard.ports

                    RowLayout {
                        id: cardPortRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("%1 latency").arg(cardPortRow.modelData.description)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }

                        IconButton {
                            type: IconButton.Tonal
                            icon: "remove"
                            font: Tokens.font.icon.small
                            implicitHeight: 26
                            disabled: cardPortRow.modelData.latencyOffsetMs <= -500
                            onClicked: Audio.setPortLatencyOffset(hwCard.cardName, cardPortRow.modelData.name, Math.max(-500, cardPortRow.modelData.latencyOffsetMs - 5))
                        }

                        StyledText {
                            Layout.minimumWidth: 56
                            horizontalAlignment: Text.AlignHCenter
                            text: `${cardPortRow.modelData.latencyOffsetMs} ms`
                            font: Tokens.font.label.small
                        }

                        IconButton {
                            type: IconButton.Tonal
                            icon: "add"
                            font: Tokens.font.icon.small
                            implicitHeight: 26
                            disabled: cardPortRow.modelData.latencyOffsetMs >= 2000
                            onClicked: Audio.setPortLatencyOffset(hwCard.cardName, cardPortRow.modelData.name, Math.min(2000, cardPortRow.modelData.latencyOffsetMs + 5))
                        }
                    }
                }
            }
        }
    }
}
