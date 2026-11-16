pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    readonly property bool shouldBeActive: x > 0 || content.hasCurrent
    property real offsetScale: 1

    // Drop motion: the popout grows as a droplet out of the bar at its button
    // (components/DropMotion.qml)
    readonly property real finalTop: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }
    readonly property DropMotion drop: DropMotion {
        panel: root
        screenState: null
        edge: "left"
        fullAlong: root.content.nonAnimHeight
        fullDepth: root.content.nonAnimWidth
        finalCenter: root.finalTop + root.content.nonAnimHeight / 2
        origin: root.content.currentCenter - root.borderThickness
        offsetScale: root.offsetScale
        open: root.shouldBeActive && !root.content.isDetached
    }
    readonly property real dropRadius: drop.radius
    readonly property bool dropping: drop.active && !content.isDetached

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: dropping ? drop.depth : content.implicitWidth * (1 - offsetScale)
    implicitHeight: dropping ? drop.along : content.implicitHeight

    x: content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : 0
    // (dropping: centred on the droplet, which moves from the button to the popout's place)
    y: dropping ? finalTop + (content.nonAnimHeight - height) / 2 + drop.offset : finalTop

    ShellMotion {
        target: root
        to: root.shouldBeActive ? 0 : 1
    }

    Behavior on x {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        // (moving between popouts; not while the drop grows: it sets y itself)
        enabled: root.offsetScale < 1 && (!root.dropping || root.offsetScale < 0.01)

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        opacity: root.dropping ? root.drop.contentOpacity : 1
        anchors.verticalCenter: parent.verticalCenter
        // (dropping: still at its place while the droplet grows over it)
        anchors.verticalCenterOffset: root.dropping ? -root.drop.offset : 0
        anchors.left: parent.left
        anchors.leftMargin: root.dropping ? 0 : (-implicitWidth - 5) * root.offsetScale
    }
}
