import QtQuick
import Caelestia.Components

Item {
    id: root

    property real radius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius
    property color color: "transparent"
    default property alias contentData: contentItem.data
    readonly property bool useMask: GraphicsInfo.api !== GraphicsInfo.Software

    clip: !useMask

    Rectangle {
        anchors.fill: parent
        visible: !root.useMask
        color: root.color
    }

    Item {
        id: contentItem

        anchors.fill: parent
    }

    ShaderEffectSource {
        id: source

        hideSource: root.useMask
        sourceItem: root.useMask ? contentItem : null
    }

    RoundedMask {
        anchors.fill: parent
        visible: root.useMask
        source: source
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        color: root.color
    }

    Behavior on color {
        CAnim {}
    }
}
