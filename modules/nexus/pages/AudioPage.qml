pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    property real micLevel: 0
    property string micTestState: ""

    Component.onCompleted: Audio.refreshCards()

    title: Tr.tr("Sound")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Output
        SectionHeader {
            text: Tr.trCtx("Output", "audio output")
        }

        SliderRow {
            visible: !!Audio.sink
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            iconClickable: true
            label: Tr.tr("Volume")
            subtext: Tr.tr("Tap the speaker icon to mute or unmute")
            valueLabel: Audio.muted ? Tr.tr("Muted") : Strings.percentOne(value)
            value: Audio.volume
            enabled: !!Audio.sink
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.setStreamMuted(Audio.sink, !Audio.muted)
        }

        AudioDeviceList {
            nodes: Audio.sinks
            currentId: Audio.sink?.id ?? -1
            iconName: "speaker"
            placeholderIcon: "speaker"
            placeholderText: Tr.trCtx("No output devices", "no audio outputs")
            onSelected: node => Audio.setAudioSink(node)
        }

        // Input
        SectionHeader {
            text: Tr.trCtx("Input", "audio input")
        }

        SliderRow {
            visible: !!Audio.source
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            iconClickable: true
            label: Tr.tr("Volume")
            subtext: Tr.tr("Tap the microphone icon to mute or unmute")
            valueLabel: Audio.sourceMuted ? Tr.tr("Muted") : Strings.percentOne(value)
            value: Audio.sourceVolume
            enabled: !!Audio.source
            onMoved: v => Audio.setSourceVolume(v)
            onIconClicked: Audio.setStreamMuted(Audio.source, !Audio.sourceMuted)
        }

        AudioDeviceList {
            nodes: Audio.sources
            currentId: Audio.source?.id ?? -1
            iconName: "mic"
            placeholderIcon: "mic_off"
            placeholderText: Tr.trCtx("No input devices", "no audio inputs")
            onSelected: node => Audio.setAudioSource(node)
        }

        ConnectedRect {
            visible: !!Audio.source
            Layout.fillWidth: true
            implicitHeight: micMeterRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: micMeterRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "graphic_eq"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("Microphone level")
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: root.micTestState === "recording" ? Tr.tr("Recording 3 s…") : root.micTestState === "playing" ? Tr.tr("Playing back…") : Audio.sourceMuted ? Tr.tr("Muted") : `${Math.round(root.micLevel * 100)}%`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHighest

                        StyledRect {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(1, Audio.sourceMuted ? 0 : root.micLevel)) * parent.width
                            radius: parent.radius
                            color: root.micLevel > 0.85 ? Colours.palette.m3error : Colours.palette.m3primary

                            Behavior on width {
                                NumberAnimation {
                                    duration: 60
                                }
                            }
                        }
                    }
                }

                TextButton {
                    text: root.micTestState === "recording" ? Tr.tr("Recording…") : root.micTestState === "playing" ? Tr.tr("Playing…") : Tr.tr("Test mic (3 s)")
                    type: TextButton.Tonal
                    disabled: root.micTestState !== "" || Audio.sourceMuted
                    onClicked: {
                        root.micTestState = "recording";
                        micTestProc.running = true;
                    }
                }
            }
        }

        // Device hardware profiles & codecs
        SectionHeader {
            visible: Audio.cards.length > 0
            text: Tr.tr("Device profiles & codecs")
        }

        Repeater {
            model: Audio.cards

            SelectRow {
                id: cardRow

                required property var modelData

                label: modelData.label
                subtext: Tr.tr("Hardware profile or Bluetooth codec")
                segmentedAllowed: false
                menuItems: profileItems.instances
                active: profileItems.instances.find(i => i.value === cardRow.modelData.activeProfile) ?? null
                fallbackText: cardRow.modelData.activeProfile
                onSelected: item => Audio.setCardProfile(cardRow.modelData.name, String(item.value))

                Variants {
                    id: profileItems

                    model: cardRow.modelData.profiles

                    MenuItem {
                        required property var modelData

                        text: modelData.description
                        value: modelData.name
                    }
                }
            }
        }

        // Volume mixer
        SectionHeader {
            text: Tr.tr("Volume mixer")
        }

        NavRow {
            icon: "tune"
            text: Tr.tr("App volumes")
            subtext: {
                const play = Audio.streams.length;
                const rec = Audio.recordingStreams.length;
                if (play === 0 && rec === 0)
                    return Tr.tr("No apps using audio");
                const parts = [];
                if (play > 0)
                    parts.push(Tr.trN("%n app playing audio", "%n apps playing audio", play));
                if (rec > 0)
                    parts.push(Tr.trN("%n app recording audio", "%n apps recording audio", rec));
                return parts.join(" · ");
            }
            onClicked: root.nState.openSubPage(1)
        }

        SectionHeader {
            text: Tr.tr("Volume controls")
        }

        StepperRow {
            label: Tr.tr("Volume step")
            subtext: Tr.tr("Amount the volume changes per scroll or key press (%)")
            value: Math.round(GlobalConfig.services.audioIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.audioIncrement = v / 100
        }

        StepperRow {
            label: Tr.tr("Max volume")
            subtext: Tr.tr("Upper limit for output volume (%)")
            value: Math.round(GlobalConfig.services.maxVolume * 100)
            from: 50
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.services.maxVolume = v / 100
        }

        // Sounds: a chime for notifications (the shell plays it), and apps'
        // own event sounds (GTK)
        SectionHeader {
            text: Tr.tr("Sounds")
        }

        ToggleRow {
            text: Tr.tr("Notification sound")
            subtext: Tr.tr("When a notification pops up (not quiet or low-priority ones)")
            checked: NotifRules.sound
            onToggled: NotifRules.setSound(checked, "")
        }

        SelectRow {
            visible: NotifRules.sound
            label: Tr.tr("Sound")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Message")
                    value: "/usr/share/sounds/freedesktop/stereo/message.oga"
                },
                MenuItem {
                    text: Tr.tr("New message")
                    value: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
                },
                MenuItem {
                    text: Tr.tr("Bell")
                    value: "/usr/share/sounds/freedesktop/stereo/bell.oga"
                },
                MenuItem {
                    text: Tr.tr("Complete")
                    value: "/usr/share/sounds/freedesktop/stereo/complete.oga"
                },
                MenuItem {
                    text: Tr.tr("Information")
                    value: "/usr/share/sounds/freedesktop/stereo/dialog-information.oga"
                }
            ]
            active: menuItems.find(i => i.value === NotifRules.soundFile) ?? null
            fallbackText: NotifRules.soundFile.split("/").pop()
            onSelected: item => {
                NotifRules.setSound(true, item.value);
                NotifRules.play(item.value); // a preview
            }
        }

        RowButton {
            visible: NotifRules.sound
            icon: "play_arrow"
            text: Tr.tr("Test notification sound")
            subtext: Tr.tr("Plays the selected chime")
            onClicked: NotifRules.play("")
        }

        ToggleRow {
            text: Tr.tr("Sounds in apps")
            subtext: Tr.tr("Event sounds of apps that play them (e.g. a click or an error)")
            checked: AppLook.get("org.gnome.desktop.sound", "event-sounds", true)
            onToggled: AppLook.set("org.gnome.desktop.sound", "event-sounds", checked)
        }

        Process {
            id: micMeterProc

            running: root.visible && !!Audio.source && !Audio.sourceMuted && root.micTestState === ""
            command: ["sh", "-c", "parec --raw --format=s16le --rate=8000 --channels=1 --property=application.name=caelestia 2>/dev/null | python3 -u -c 'import array, sys\ns = sys.stdin.buffer\nwhile True:\n d = s.read(640)\n if not d: break\n a = array.array(\"h\")\n a.frombytes(d[:len(d) - (len(d) & 1)])\n peak = max((abs(x) for x in a), default=0) / 32768.0\n print(f\"{min(1.0, peak * 2.5):.3f}\", flush=True)'"]
            onRunningChanged: if (!running)
                root.micLevel = 0
            stdout: SplitParser {
                onRead: line => {
                    const v = parseFloat(line.trim());
                    if (!isNaN(v))
                        root.micLevel = v;
                }
            }
        }

        Process {
            id: micTestProc

            command: ["sh", "-c", "f=/tmp/caelestia-mic-test.wav; rm -f \"$f\"; timeout 3 parecord --file-format=wav --property=application.name=caelestia \"$f\" >/dev/null 2>&1 || true; echo playing; pw-play \"$f\" >/dev/null 2>&1 || true; rm -f \"$f\""]
            stdout: SplitParser {
                onRead: line => {
                    if (line.trim() === "playing")
                        root.micTestState = "playing";
                }
            }
            onExited: root.micTestState = ""
        }
    }
}
