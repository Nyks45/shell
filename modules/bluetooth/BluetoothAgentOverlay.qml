pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.components.containers
import qs.services

// Screen overlay for incoming Bluetooth pairing prompts when no Settings window has focus.
LazyLoader {
    id: root

    readonly property bool shown: BluetoothAgent.active && BluetoothAgent.decided && !BluetoothAgent.host

    active: shown

    StyledWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
        name: "bluetooth-agent"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        StyledRect {
            id: dim

            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.32)
            opacity: 0
            Component.onCompleted: opacity = 1

            Behavior on opacity {
                Anim {}
            }

            MouseArea {
                anchors.fill: parent
            }
        }

        BluetoothAgentCard {
            id: card

            anchors.centerIn: parent
            scale: 0.92
            opacity: 0
            Component.onCompleted: {
                scale = 1;
                opacity = 1;
                forceActiveFocus();
            }

            Behavior on scale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            Behavior on opacity {
                Anim {}
            }
        }
    }
}
