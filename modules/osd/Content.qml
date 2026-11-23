pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.dashboard.mini
import qs.modules.nexus

Item {
    id: root

    required property Brightness.Monitor monitor
    required property ScreenState screenState

    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness

    property real expandProg: root.screenState.osdExpanded ? 1 : 0
    readonly property int mixerTargetW: 548
    readonly property int mixerTargetH: Math.min(500, ((QsWindow.window as QsWindow)?.screen?.height ?? 1080) - 160)

    Behavior on expandProg {
        Anim {}
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.screenState.osdExpanded
        onActivated: {
            root.screenState.osdExpanded = false;
            root.screenState.osd = false;
        }
    }

    // A floating island: even padding all round (expands leftward on arrow click)
    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: root.expandProg > 0.01 ? Tokens.spacing.medium * root.expandProg : 0

        Item {
            id: mixerBox

            visible: root.expandProg > 0.002
            clip: true
            Layout.preferredWidth: root.mixerTargetW * root.expandProg
            Layout.preferredHeight: Math.max(railLayout.implicitHeight, root.mixerTargetH * root.expandProg)

            Loader {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root.mixerTargetW
                height: root.mixerTargetH
                active: root.screenState.osdExpanded || root.expandProg > 0.002
                opacity: Math.max(0, (root.expandProg - 0.35) / 0.65)

                sourceComponent: AudioMixer {
                    compact: true
                    showCloseButton: false
                    active: root.screenState.osdExpanded
                    onCloseRequested: root.screenState.osdExpanded = false
                    onSettingsRequested: id => {
                        root.screenState.osdExpanded = false;
                        root.screenState.osd = false;
                        WindowFactory.createAt(id, []);
                    }
                }
            }
        }

        ColumnLayout {
            id: railLayout

            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.medium

            // Speaker volume
            CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0)
                        Audio.incrementVolume();
                    else if (event.angleDelta.y < 0)
                        Audio.decrementVolume();
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    anchors.fill: parent

                    icon: Icons.getVolumeIcon(value, root.muted)
                    value: root.volume
                    to: GlobalConfig.services.maxVolume
                    onMoved: Audio.setVolume(value)
                }
            }

            // Microphone volume
            WrappedLoader {
                shouldBeActive: Config.osd.enableMicrophone && !Config.osd.enableBrightness

                sourceComponent: CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        if (event.angleDelta.y > 0)
                            Audio.incrementSourceVolume();
                        else if (event.angleDelta.y < 0)
                            Audio.decrementSourceVolume();
                    }

                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight

                    FilledSlider {
                        anchors.fill: parent

                        icon: Icons.getMicVolumeIcon(value, root.sourceMuted)
                        value: root.sourceVolume
                        to: GlobalConfig.services.maxVolume
                        onMoved: Audio.setSourceVolume(value)
                    }
                }
            }

            // Brightness
            WrappedLoader {
                shouldBeActive: Config.osd.enableBrightness

                sourceComponent: CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        const monitor = root.monitor;
                        if (!monitor)
                            return;
                        if (event.angleDelta.y > 0)
                            monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
                        else if (event.angleDelta.y < 0)
                            monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
                    }

                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight

                    FilledSlider {
                        anchors.fill: parent

                        icon: `brightness_${(Math.round(value * 6) + 1)}`
                        value: root.brightness
                        onMoved: root.monitor?.setBrightness(value)
                    }
                }
            }

            // Expand / collapse arrow to open full Sound controls on the left
            IconButton {
                Layout.alignment: Qt.AlignHCenter
                type: root.screenState.osdExpanded ? IconButton.Filled : IconButton.Tonal
                isToggle: true
                followChecked: true
                checked: root.screenState.osdExpanded
                icon: root.screenState.osdExpanded ? "chevron_right" : "chevron_left"
                implicitHeight: Tokens.sizes.osd.sliderWidth
                onClicked: root.screenState.osdExpanded = !root.screenState.osdExpanded
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool shouldBeActive

        asynchronous: true
        Layout.preferredHeight: shouldBeActive ? Tokens.sizes.osd.sliderHeight : 0
        opacity: shouldBeActive ? 1 : 0
        active: opacity > 0
        visible: active

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.Emphasized
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
