import QtQuick
import QtQuick.Effects
import M3Shapes
import qs.services

// A glass surface in a Material 3 shape: the tint, and the top light cut to the shape (it stays
// upright while the shape turns).
// From Nebula (github.com/LilaccFlowerr/Nebula, AGPL-3.0), components/GlassShape.qml.
MaterialShape {
    id: root

    property color fill: Colours.palette.m3surfaceContainerHigh
    property real tint: Colours.glass.tint
    property real light: Colours.glass.topLight

    color: Qt.alpha(fill, tint)

    MaterialShape {
        id: mask

        anchors.fill: parent
        shape: root.shape
        animationDuration: root.animationDuration
        animationEasing: root.animationEasing
        color: "black"
        visible: false
        layer.enabled: true
    }

    Item {
        id: lightLayer

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.5
            height: parent.height * 1.5
            rotation: -root.rotation
            gradient: Gradient {
                GradientStop {
                    position: 0.17
                    color: Qt.rgba(1, 1, 1, root.light)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.light > 0
        source: lightLayer
        maskEnabled: true
        maskSource: mask
    }
}
