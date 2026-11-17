pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

// The pill's menus: a window's previews (the taskbar) and the tray's menus, one at a time
Item {
    id: root

    required property ShellScreen screen
    required property real offsetScale

    readonly property alias content: content

    readonly property real nonAnimWidth: content.implicitWidth
    readonly property real nonAnimHeight: content.implicitHeight
    readonly property Item current: (content.item as Item)?.current ?? null

    property alias currentName: popoutState.currentName
    property alias hasCurrent: popoutState.hasCurrent
    property alias taskbarWs: popoutState.taskbarWs
    property alias taskbarKey: popoutState.taskbarKey
    property real currentCenter

    // Dummy object so Tokens attached prop resolves to global config
    // Anim configs are not per-monitor
    readonly property QtObject dummy: QtObject {}
    readonly property int animLength: dummy.Tokens.anim.durations.expressiveDefaultSpatial
    readonly property var animCurve: dummy.Tokens.anim.expressiveDefaultSpatial // The easingCurve type is Qt 6.11+ so we gotta use var for now

    function close(): void {
        hasCurrent = false;
    }

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    focus: hasCurrent
    Keys.onEscapePressed: close()

    PopoutState {
        id: popoutState
    }

    Loader {
        id: content

        readonly property bool shouldBeActive: root.hasCurrent

        anchors.fill: parent
        active: false
        opacity: 0

        onActiveChanged: {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    popouts: popoutState
                });
        }

        // Makes the loader load on the same frame shouldBeActive becomes true, which ensures size is set
        states: State {
            name: "active"
            when: content.shouldBeActive

            PropertyChanges {
                content.opacity: 1
                content.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }

    Behavior on implicitWidth {
        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }

    Behavior on implicitHeight {
        enabled: root.offsetScale < 1

        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }
}
