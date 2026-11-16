pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property bool sidebarVisible
    readonly property real nonAnimWidth: content.implicitWidth

    readonly property bool shouldBeActive: screenState.session && Config.session.enabled && !screenState.sessionAtBar
    property real offsetScale: 1
    // Wave motion: rises and spreads from where it was opened (components/WaveMotion.qml)
    readonly property WaveMotion drop: WaveMotion {
        panel: root
        screenState: root.screenState
        edge: "right"
        fullAlong: root.content.implicitHeight || 510
        fullDepth: root.content.implicitWidth
        space: root.parent?.parent ?? null
        finalCenter: (space?.height ?? 0) / 2
        offsetScale: root.offsetScale
        open: root.shouldBeActive
    }
    readonly property real dropRadius: drop.radius
    readonly property alias content: content

    property real sidebarOffset: sidebarVisible ? 14 : 0

    visible: offsetScale < 1
    anchors.rightMargin: drop.active ? 0 : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: drop.active ? drop.depth : content.implicitWidth
    clip: true // (the drop reveals the content; always on: toggling it left rounded masks black)
    implicitHeight: drop.active ? drop.along : content.implicitHeight || 510 // Hard coded fallback for first open
    opacity: drop.active ? 1 : 1 - offsetScale

    ShellMotion {
        target: root
        to: root.shouldBeActive ? 0 : 1
    }

    Loader {
        id: content

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState
                });
        }

        opacity: root.drop.contentOpacity
        // Where it sits: one expression (never swapped anchors); with the drop, at its final
        // place while the wave grows over it
        x: root.drop.active ? root.width - root.drop.fullDepth : 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.drop.offset

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
