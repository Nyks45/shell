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
    property real offsetScale: content.hasCurrent ? 0 : 1
    // The popouts are islands of their own, a gap away from the pill, and grow out of the
    // hovered icon (the drawers draw that shape from `morph`, ContentWindow)
    readonly property real morph: 1 - offsetScale

    visible: width > 0 && height > 0

    implicitWidth: offsetScale < 1 ? content.implicitWidth : 0
    implicitHeight: content.implicitHeight

    // (the gap after the pill is the bar's own strip: crossing it keeps the menu)
    y: {
        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on y {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        // (its shape grows behind it: the contents only show once it's nearly there)
        opacity: Math.min(1, Math.max(0, (root.morph - 0.8) / 0.2))
    }
}
