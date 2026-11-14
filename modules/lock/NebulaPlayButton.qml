import QtQuick
import M3Shapes

Item {
    id: root

    property bool playing: false
    property bool enabled: true
    property real size: NebulaTheme.button.playSize
    property real iconSize: NebulaTheme.button.playIconSize
    property color color: NebulaTheme.colors.primaryContainer
    property color hoverColor: NebulaTheme.colors.primary
    property color iconColor: NebulaTheme.colors.textOnPrimaryContainer
    property color hoverIconColor: NebulaTheme.colors.textOnPrimary

    signal clicked()

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.45
    scale: mouse.pressed ? 0.9 : mouse.containsMouse ? 1.05 : 1

    Behavior on scale {
        NumberAnimation {
            duration: NebulaTheme.anim.fast
            easing.type: Easing.OutBack
            easing.overshoot: NebulaTheme.anim.overshoot
        }
    }

    MaterialShape {
        anchors.fill: parent
        implicitSize: parent.width
        shape: root.playing ? MaterialShape.Cookie9Sided : MaterialShape.Pentagon
        color: mouse.containsMouse ? root.hoverColor : root.color
        animationDuration: NebulaTheme.anim.slow

        Behavior on color {
            ColorAnimation {
                duration: NebulaTheme.anim.fast
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.playing ? "pause" : "play_arrow"
        font.family: NebulaTheme.font.icons
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
