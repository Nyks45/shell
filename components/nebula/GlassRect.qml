import QtQuick
import qs.services

// A glass surface: a translucent tint with a soft light across the top (the blur behind it is
// the compositor's, on the layer the surface is drawn in).
// From Nebula (github.com/LilaccFlowerr/Nebula, AGPL-3.0), components/GlassRect.qml.
Rectangle {
    id: root

    property color fill: Colours.palette.m3surfaceContainerHigh
    property real tint: Colours.glass.tint
    property real light: Colours.glass.topLight

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
