import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property real iconOffset: 0
    property bool enabled: true

    signal clicked()

    implicitWidth: LockTheme.button.size
    implicitHeight: LockTheme.button.size
    radius: LockTheme.radius.full
    opacity: enabled ? 1 : 0.4
    color: mouse.pressed ? LockTheme.colors.surfaceContainerHighest
        : mouse.containsMouse ? LockTheme.colors.surfaceContainerHigh
        : LockTheme.colors.surfaceContainer

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.iconOffset
        text: root.icon
        font.family: LockTheme.font.icons
        font.pixelSize: LockTheme.button.iconSize
        color: LockTheme.colors.textOnSurface
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
