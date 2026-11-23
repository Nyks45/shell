import QtQuick
import M3Shapes

Item {
    id: root

    property bool playing: false
    property bool enabled: true
    property real size: LockTheme.button.playSize
    property real iconSize: LockTheme.button.playIconSize
    property color color: LockTheme.colors.primaryContainer
    property color hoverColor: LockTheme.colors.primary
    property color iconColor: LockTheme.colors.textOnPrimaryContainer
    property color hoverIconColor: LockTheme.colors.textOnPrimary

    signal clicked()

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.45
    scale: mouse.pressed ? 0.9 : mouse.containsMouse ? 1.05 : 1

    Behavior on scale {
        NumberAnimation {
            duration: LockTheme.anim.fast
            easing.type: Easing.OutBack
            easing.overshoot: LockTheme.anim.overshoot
        }
    }

    MaterialShape {
        anchors.fill: parent
        implicitSize: parent.width
        shape: root.playing ? MaterialShape.Cookie9Sided : MaterialShape.Pentagon
        color: mouse.containsMouse ? root.hoverColor : root.color
        animationDuration: LockTheme.anim.slow

        Behavior on color {
            ColorAnimation {
                duration: LockTheme.anim.fast
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.playing ? "pause" : "play_arrow"
        font.family: LockTheme.font.icons
        font.pixelSize: root.iconSize
        color: mouse.containsMouse ? root.hoverIconColor : root.iconColor
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
