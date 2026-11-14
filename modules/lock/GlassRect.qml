import QtQuick

Rectangle {
    id: root

    property color fill: NebulaTheme.colors.surfaceContainerHigh
    property real tint: NebulaTheme.glass.tint
    property real light: NebulaTheme.glass.topLight

    color: Qt.alpha(fill, tint)

    Rectangle {
        anchors.fill: parent
        visible: root.light > 0
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, root.light)
            }
            GradientStop {
                position: 0.58
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }
}
