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

    // With the Nebula launcher style the ring opens instead (modules/nebula/NebulaLauncher.qml)
    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled && GlobalConfig.appearance.style.launcher !== "nebula"

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: 1

    property real closingHeight

    readonly property WaveMotion drop: WaveMotion {
        panel: root
        screenState: root.screenState
        edge: "bottom"
        fullAlong: root.content.implicitWidth || 630
        fullDepth: root.shouldBeActive ? root.content.implicitHeight : root.closingHeight
        finalCenter: (root.parent?.width ?? 0) / 2
        offsetScale: root.offsetScale
        open: root.shouldBeActive
    }
    readonly property real dropRadius: drop.radius
    readonly property alias content: content

    function heightFor(h: real): real {
        return drop.active ? drop.depth : h;
    }

    // Switching style while running: back to the live height (a close may have fixed it)
    // Switching style while running: back to the live height (a close may have fixed it)
    readonly property bool dropOn: drop.active
    onDropOnChanged: implicitHeight = Qt.binding(() => heightFor(content.implicitHeight))

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => heightFor(content.implicitHeight));
        else if (drop.active) {
            // the height it had, shrinking (its content can change size while closing)
            closingHeight = content.implicitHeight;
            implicitHeight = Qt.binding(() => heightFor(closingHeight));
        } else
            implicitHeight = implicitHeight; // Break binding during close anim
    }

    // (the drop spring nears "closed" slowly: hidden in its last 0.2%, nothing left behind)
    visible: offsetScale < 1
    anchors.bottomMargin: drop.active ? 0 : (-implicitHeight - 5) * offsetScale
    anchors.horizontalCenterOffset: drop.offset
    implicitHeight: heightFor(content.implicitHeight)
    implicitWidth: drop.active ? drop.along : (content.implicitWidth || 630) // 630: fallback for first open
    clip: true // (the drop reveals the content; always on: toggling it left rounded masks black)
    opacity: drop.active ? 1 : 1 - offsetScale
    // (No fade on the content: it holds rounded masks that capture it into a texture, and Qt
    // doesn't capture anything at opacity 0, so they stayed black. Expanding reveals it in place.)

    Timer {
        interval: 300
        running: true
        onTriggered: Apps
    }

    ShellMotion {
        target: root
        to: root.shouldBeActive ? 0 : 1
    }

    Loader {
        id: content

        opacity: root.drop.contentOpacity


        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState,
                    panels: root.panels,
                    maxHeight: Qt.binding(() => root.maxHeight)
                });
        }

        // Where it sits: one x/y expression, never swapped anchors (swapping fixed its size at 0
        // after a style switch: an empty dashboard and notification list)
        // (expanding: stays put at the bottom edge and is revealed; sliding: moves with the panel)
        // (drop: at its final place, the bottom edge's wave growing over it)
        y: root.drop.active ? root.height - root.drop.fullDepth : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -root.drop.offset

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
