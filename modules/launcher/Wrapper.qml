pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    // With the pill bar: an island floating a gap above the bottom edge, grown out of a small
    // capsule there (like the top island out of its pill), the search bar first
    readonly property bool island: Config.bar.pill
    readonly property real floatGap: Tokens.spacing.medium
    readonly property real open: 1 - offsetScale
    // (over the last bit the capsule itself shrinks away: nothing left on the edge)
    readonly property real tail: Math.min(1, open / 0.2)
    readonly property real capW: 180
    readonly property real capH: 44
    property real fullHeight: content.implicitHeight

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            fullHeight = Qt.binding(() => content.implicitHeight);
        else
            fullHeight = fullHeight; // Break binding during close anim
    }

    readonly property real fullWidth: content.implicitWidth || 630 // Hard coded fallback for first open

    visible: offsetScale < 1
    anchors.bottomMargin: island ? floatGap : (-implicitHeight - 5) * offsetScale
    implicitHeight: island ? (capH + (fullHeight - capH) * open) * tail : fullHeight
    implicitWidth: island ? (capW + (fullWidth - capW) * open) * tail : fullWidth
    clip: island
    // (the island's contents fade in once it has grown enough to hold them)
    opacity: island ? Math.min(1, Math.max(0, (open - 0.35) / 0.5)) : 1 - offsetScale

    Timer {
        interval: 300
        running: true
        onTriggered: Apps
    }

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState,
                    panels: root.panels,
                    maxHeight: Qt.binding(() => root.maxHeight)
                });
        }

        // (the island reveals it from the bottom: the search bar first)
        anchors.top: root.island ? undefined : parent.top
        anchors.bottom: root.island ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
