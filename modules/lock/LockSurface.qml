pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import Caelestia.Config

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam
    property bool bootLock: false

    readonly property alias unlocking: scene.closing

    contentItem.Config.screen: screen ? screen.name : ""
    contentItem.Tokens.screen: screen ? screen.name : ""

    color: "transparent"

    Connections {
        target: root.lock

        function onUnlock(): void {
            scene.startUnlock();
        }
    }

    LockScene {
        id: scene

        anchors.fill: parent
        focus: true
        pam: root.pam
        screen: root.screen
        bootLock: root.bootLock
        onUnlocked: root.lock.locked = false
    }

    Component.onCompleted: scene.forceActiveFocus()
}
