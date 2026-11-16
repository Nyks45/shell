pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState

    readonly property real nonAnimHeight: (content.item as Item)?.nonAnimHeight ?? 0
    readonly property bool shouldBeActive: screenState.dashboard && Config.dashboard.enabled
    property real offsetScale: 1

    // (the drop spring nears "closed" slowly: hidden in its last 0.2%, nothing left behind)
    visible: offsetScale < 1

    // Drop motion: grows out of where it was opened from (components/DropMotion.qml)
    readonly property DropMotion drop: DropMotion {
        panel: root
        screenState: root.screenState
        edge: "top"
        fullAlong: root.content.implicitWidth || 854
        fullDepth: root.content.implicitHeight
        finalCenter: (root.parent?.width ?? 0) / 2
        offsetScale: root.offsetScale
        open: root.shouldBeActive
    }
    readonly property real dropRadius: drop.radius
    readonly property alias content: content

    anchors.topMargin: drop.active ? 0 : (-implicitHeight - 5) * offsetScale
    anchors.horizontalCenterOffset: drop.offset
    implicitHeight: drop.active ? drop.depth : content.implicitHeight
    implicitWidth: drop.active ? drop.along : (content.implicitWidth || 854) // 854: fallback for first open
    clip: true // (the drop reveals the content; always on: toggling it left rounded masks black)
    opacity: drop.active ? 1 : 1 - offsetScale
    // (No fade on the content: it holds rounded masks that capture it into a texture, and Qt
    // doesn't capture anything at opacity 0, so they stayed black. Expanding reveals it in place.)

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
                    screenState: root.screenState
                });
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -root.drop.offset // (still while the drop moves)
        // Where it sits: one x/y expression, never swapped anchors (swapping fixed its size at 0
        // after a style switch: an empty dashboard and notification list)
        // (expanding: stays put at the top and is revealed; sliding: moves with the panel's bottom)
        y: root.drop.active ? 0 : parent.height - height

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
