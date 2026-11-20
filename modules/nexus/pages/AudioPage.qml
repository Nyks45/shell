pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Sound")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Output
        SliderRow {
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            label: Tr.trCtx("Output", "audio output")
            valueLabel: Strings.percentOne(value)
            value: Audio.volume
            enabled: !!Audio.sink && !Audio.muted
            onMoved: v => Audio.setVolume(v)
        }

        ToggleRow {
            text: Tr.trCtx("Muted", "audio output muted")
            checked: Audio.muted
            disabled: !Audio.sink
            onToggled: Audio.setStreamMuted(Audio.sink, checked)
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
        SliderRow {
            groupStart: true
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            label: Tr.trCtx("Input", "audio input")
            valueLabel: Strings.percentOne(value)
            value: Audio.sourceVolume
            enabled: !!Audio.source && !Audio.sourceMuted
            onMoved: v => Audio.setSourceVolume(v)
        }

        ToggleRow {
            text: Tr.trCtx("Muted", "audio input muted")
            checked: Audio.sourceMuted
            disabled: !Audio.source
            onToggled: Audio.setStreamMuted(Audio.source, checked)
        }

        AudioDeviceList {
            nodes: Audio.sources
            currentId: Audio.source?.id ?? -1
            iconName: "mic"
            placeholderIcon: "mic_off"
            placeholderText: Tr.trCtx("No input devices", "no audio inputs")
            onSelected: node => Audio.setAudioSource(node)
        }

        // Per-app volumes
        NavRow {
            groupStart: true

            icon: "tune"
            text: Tr.tr("App volumes")
            subtext: Audio.streams.length === 0 ? Tr.tr("No apps playing audio") : Tr.trN("%n app playing audio", "%n apps playing audio", Audio.streams.length)
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

        ToggleRow {
            text: Tr.tr("Sounds in apps")
            subtext: Tr.tr("Event sounds of apps that play them (e.g. a click or an error)")
            checked: AppLook.get("org.gnome.desktop.sound", "event-sounds", true)
            onToggled: AppLook.set("org.gnome.desktop.sound", "event-sounds", checked)
        }
    }
}
