import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property real iconOffset: 0
    property bool enabled: true

    signal clicked()

    implicitWidth: NebulaTheme.button.size
    implicitHeight: NebulaTheme.button.size
    radius: NebulaTheme.radius.full
    opacity: enabled ? 1 : 0.4
    color: mouse.pressed ? NebulaTheme.colors.surfaceContainerHighest
        : mouse.containsMouse ? NebulaTheme.colors.surfaceContainerHigh
        : NebulaTheme.colors.surfaceContainer

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.iconOffset
        text: root.icon
        font.family: NebulaTheme.font.icons
        font.pixelSize: NebulaTheme.button.iconSize
        color: NebulaTheme.colors.textOnSurface
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
