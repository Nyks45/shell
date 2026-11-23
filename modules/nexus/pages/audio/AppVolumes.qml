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
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("App volumes")
    isSubPage: true

    Component.onCompleted: Audio.openCards()
    Component.onDestruction: Audio.closeCards()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        AudioPeakMonitor {
            id: peakMonitor

            active: root.visible
            targets: [...Audio.streams, ...Audio.recordingStreams].map(n => ({
                        serial: Audio.nodeKey(n),
                        captureSink: false
                    })).filter(t => !!t.serial)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.medium
            text: Tr.tr("Adjust the volume and device of apps playing or recording audio.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            text: Tr.tr("Apps playing audio")
        }

        Repeater {
            model: ScriptModel {
                values: [...Audio.streams]
            }

            delegate: StreamCard {
                isRecording: false
            }

            onCountChanged: Rows.bump(parent)
        }

        EmptyCard {
            visible: Audio.streams.length === 0
            icon: "music_off"
            text: Tr.tr("No apps playing audio")
        }

        SectionHeader {
            text: Tr.tr("Apps recording audio")
        }

        Repeater {
            model: ScriptModel {
                values: [...Audio.recordingStreams]
            }

            delegate: StreamCard {
                isRecording: true
            }

            onCountChanged: Rows.bump(parent)
        }

        EmptyCard {
            visible: Audio.recordingStreams.length === 0
            icon: "mic_off"
            text: Tr.tr("No apps recording audio")
        }
    }

    component EmptyCard: ConnectedRect {
        id: empty

        required property string icon
        required property string text

        Layout.fillWidth: true
        implicitHeight: emptyCol.implicitHeight + Tokens.padding.extraLarge * 2

        ColumnLayout {
            id: emptyCol

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: empty.icon
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: empty.text
                color: Colours.palette.m3outline
                font: Tokens.font.body.large
            }
        }
    }

    component StreamCard: ColumnLayout {
        id: streamCard

        required property PwNode modelData
        required property int index
        property bool isRecording: false

        readonly property string serial: Audio.nodeKey(modelData)
        readonly property bool muted: modelData?.audio?.muted ?? false
        readonly property real maxVol: Math.max(1, GlobalConfig.services.maxVolume)
        readonly property real vol: modelData?.audio?.volume ?? 0
        readonly property real peak: muted ? 0 : Number(peakMonitor.peaks[serial] ?? 0)
        readonly property string mediaName: String(modelData?.properties?.["media.name"] ?? "")
        readonly property string appTitle: Audio.getStreamName(modelData)
        readonly property PwNode linkedDevice: {
            if (!modelData)
                return null;
            const g = streamLinks.linkGroups.find(l => isRecording ? l.target === modelData : l.source === modelData);
            return g ? (isRecording ? g.source : g.target) : null;
        }
        readonly property string activeRouteValue: Audio.streamRouteName(isRecording ? "recording" : "playback", modelData, linkedDevice)
        readonly property var routeChoices: {
            const devices = isRecording ? Audio.sources : Audio.sinks;
            const out = devices.map(d => ({
                        value: String(d.name ?? ""),
                        label: Audio.friendlyDeviceName(d),
                        isMonitor: false
                    }));
            if (isRecording) {
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

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall / 2

        PwNodeLinkTracker {
            id: streamLinks

            node: streamCard.modelData
        }

        SliderRow {
            icon: streamCard.isRecording ? Icons.getMicVolumeIcon(streamCard.vol, streamCard.muted) : Icons.getVolumeIcon(streamCard.vol, streamCard.muted)
            iconClickable: true
            label: streamCard.appTitle
            subtext: streamCard.mediaName && streamCard.mediaName !== streamCard.appTitle ? streamCard.mediaName : ""
            valueLabel: streamCard.muted ? Tr.tr("Muted") : `${Math.round(streamCard.vol * 100)}% · ${Audio.volumeDb(streamCard.vol)}`
            value: Math.min(1, streamCard.vol / streamCard.maxVol)
            peak: streamCard.peak
            enabled: true
            onMoved: v => Audio.setStreamVolume(streamCard.modelData, v * streamCard.maxVol)
            onIconClicked: Audio.setStreamMuted(streamCard.modelData, !Audio.getStreamMuted(streamCard.modelData))
        }

        SelectRow {
            id: deviceSelect

            visible: streamCard.routeChoices.length > 0
            label: streamCard.isRecording ? Tr.tr("Input device") : Tr.tr("Output device")
            segmentedAllowed: false
            fallbackText: {
                if (streamCard.activeRouteValue.endsWith(".monitor")) {
                    const base = streamCard.activeRouteValue.replace(/\.monitor$/, "");
                    const sink = Audio.sinks.find(s => s.name === base);
                    return sink ? Tr.tr("Monitor: %1").arg(Audio.friendlyDeviceName(sink)) : Tr.tr("Monitor");
                }
                return Tr.tr("Default");
            }
            menuItems: deviceItems.instances
            onSelected: item => {
                const targetName = String(item.value ?? "");
                if (!streamCard.modelData || !targetName)
                    return;
                if (streamCard.isRecording) {
                    Audio.moveRecordingToSourceName(streamCard.modelData, targetName);
                } else {
                    const targetSink = Audio.sinks.find(s => s.name === targetName);
                    if (targetSink)
                        Audio.moveStreamToSink(streamCard.modelData, targetSink);
                }
            }

            Binding {
                target: deviceSelect
                property: "active"
                value: deviceItems.instances.find(i => i.value === streamCard.activeRouteValue) ?? null
            }

            Variants {
                id: deviceItems

                model: streamCard.routeChoices

                MenuItem {
                    required property var modelData

                    text: modelData.label
                    value: modelData.value
                    icon: modelData.isMonitor ? "hearing" : (streamCard.isRecording ? "mic" : "speaker")
                }
            }
        }
    }
}
