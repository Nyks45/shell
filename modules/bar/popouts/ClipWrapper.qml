pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
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

    // Wave motion: the popout rises out of the bar at its button and spreads along it
    // (components/WaveMotion.qml)
    readonly property real finalTop: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }
    // Wave motion for popouts (the power menu and the rest): a sound wave from the button that
    // was clicked or hovered. A circle grows out of the bar at the button (a half circle bulging
    // out of the bar first) until it covers the popout; the popout is what it reveals, its
    // corners settling last.
    readonly property bool dropping: GlobalConfig.appearance.style.shellAnim === "wave" && !content.isDetached
    readonly property real fullW: content.nonAnimWidth
    readonly property real fullH: content.nonAnimHeight
    readonly property real originY: Math.max(finalTop, Math.min(finalTop + fullH, content.currentCenter - borderThickness))
    readonly property real maxR: Math.hypot(fullW, Math.max(originY - finalTop, finalTop + fullH - originY))
    readonly property real waveT: Math.max(0, Math.min(1, 1 - offsetScale))
    readonly property real waveR: maxR * waveT
    readonly property real boxTop: Math.max(finalTop, originY - waveR)
    readonly property real boxBottom: Math.min(finalTop + fullH, originY + waveR)
    // Round like the wave while it's small; the popout's own corners once it covers them
    readonly property real dropRadius: {
        if (!dropping)
            return Tokens.rounding.extraLarge;
        const w = Math.min(fullW, waveR), h = boxBottom - boxTop;
        const settle = Math.max(0, Math.min(1, (waveR - Math.min(fullW, fullH / 2)) / Math.max(1, maxR - Math.min(fullW, fullH / 2))));
        const round = Math.min(w, h / 2, waveR);
        return Math.max(Math.min(Tokens.rounding.extraLarge, w, h / 2), round * (1 - settle) + Tokens.rounding.extraLarge * settle);
    }
    readonly property real waveContentOpacity: dropping ? Math.max(0.004, Math.min(1, (waveT - 0.35) / 0.4)) : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: dropping ? Math.min(fullW, waveR) : content.implicitWidth * (1 - offsetScale)
    implicitHeight: dropping ? boxBottom - boxTop : content.implicitHeight

    x: content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : 0
    // (the wave: the part of the popout it has reached)
    y: dropping ? boxTop : finalTop

    ShellMotion {
        target: root
        to: root.shouldBeActive ? 0 : 1
        waveOpenCurve: [0.2, 0.55, 0.3, 1, 1, 1]
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

        opacity: root.waveContentOpacity
        anchors.verticalCenter: parent.verticalCenter
        // (dropping: still at its place while the wave grows over it)
        anchors.verticalCenterOffset: root.dropping ? (root.finalTop + root.fullH / 2) - (root.boxTop + (root.boxBottom - root.boxTop) / 2) : 0
        anchors.left: parent.left
        anchors.leftMargin: root.dropping ? 0 : (-implicitWidth - 5) * root.offsetScale
    }
}
