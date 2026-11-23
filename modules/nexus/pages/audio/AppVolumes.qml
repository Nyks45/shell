pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("App volumes")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

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

        StreamGroup {
            streams: Audio.streams
            devices: Audio.sinks
            placeholderIcon: "music_off"
            placeholderText: Tr.tr("No apps playing audio")
        }

        SectionHeader {
            text: Tr.tr("Apps recording audio")
        }

        StreamGroup {
            streams: Audio.recordingStreams
            devices: Audio.sources
            isRecording: true
            placeholderIcon: "mic_off"
            placeholderText: Tr.tr("No apps recording audio")
        }
    }

    component StreamGroup: ItemList {
        id: group

        property var streams: []
        property var devices: []
        property bool isRecording: false

        showList: true
        color: list.count === 0 ? Colours.tPalette.m3surfaceContainer : "transparent"
        list.spacing: Tokens.spacing.medium

        model: ScriptModel {
            values: [...(group.streams ?? [])]
        }

        delegate: ColumnLayout {
            id: streamCard

            required property PwNode modelData
            required property int index
            readonly property bool muted: streamCard.modelData?.audio?.muted ?? false

            anchors.left: group.list.contentItem.left
            anchors.right: group.list.contentItem.right
            spacing: Tokens.spacing.extraSmall / 2

            SliderRow {
                icon: group.isRecording
                    ? Icons.getMicVolumeIcon(streamCard.modelData?.audio?.volume ?? 0, streamCard.muted)
                    : Icons.getVolumeIcon(streamCard.modelData?.audio?.volume ?? 0, streamCard.muted)
                iconClickable: true
                label: Audio.getStreamName(streamCard.modelData)
                valueLabel: streamCard.muted ? Tr.tr("Muted") : Strings.percentOne(value)
                value: streamCard.modelData?.audio?.volume ?? 0
                enabled: true
                onMoved: v => Audio.setStreamVolume(streamCard.modelData, v)
                onIconClicked: Audio.setStreamMuted(streamCard.modelData, !Audio.getStreamMuted(streamCard.modelData))
            }

            SelectRow {
                visible: group.devices.length > 1
                label: group.isRecording ? Tr.tr("Input device") : Tr.tr("Output device")
                segmentedAllowed: false
                fallbackText: Tr.tr("Default")
                menuItems: deviceItems.instances
                // The device the stream is linked to now (follows pactl moves):
                // playback links stream -> sink, recording links source -> stream
                active: {
                    const s = streamCard.modelData;
                    const g = streamLinks.linkGroups.find(l => group.isRecording ? l.target === s : l.source === s);
                    const dev = g ? (group.isRecording ? g.source : g.target) : null;
                    return dev ? (deviceItems.instances.find(i => i.value === dev) ?? null) : null;
                }
                onSelected: item => {
                    const target = item.value as PwNode;
                    if (group.isRecording)
                        Audio.moveRecordingToSource(streamCard.modelData, target);
                    else
                        Audio.moveStreamToSink(streamCard.modelData, target);
                }

                PwNodeLinkTracker {
                    id: streamLinks

                    node: streamCard.modelData
                }

                Variants {
                    id: deviceItems

                    model: group.devices

                    MenuItem {
                        required property PwNode modelData

                        text: Audio.friendlyDeviceName(modelData)
                        value: modelData
                    }
                }
            }
        }
    }
}
