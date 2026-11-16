pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: screenState.sidebar && Config.sidebar.enabled
    property real offsetScale: 1

    // Its full top and bottom (Panels: between the notifications and the quick settings)
    property real dropFullTop
    property real dropFullBottom
    // Drop motion: grows out of where it was opened from (components/DropMotion.qml)
    readonly property DropMotion drop: DropMotion {
        panel: root
        screenState: root.screenState
        edge: "right"
        fullAlong: Math.max(0, root.dropFullBottom - root.dropFullTop)
        fullDepth: Tokens.sizes.sidebar.width
        finalCenter: (root.dropFullTop + root.dropFullBottom) / 2
        offsetScale: root.offsetScale
        open: root.shouldBeActive
    }
    readonly property real dropRadius: drop.radius
    // How far its top and bottom sit inside the full span (Panels applies them)
    readonly property real dropInsetTop: drop.active ? Math.max(0, drop.finalCenter + drop.offset - drop.along / 2 - dropFullTop) : 0
    readonly property real dropInsetBottom: drop.active ? Math.max(0, dropFullBottom - (drop.finalCenter + drop.offset + drop.along / 2)) : 0

    visible: offsetScale < 1
    anchors.rightMargin: drop.active ? 0 : (-implicitWidth - 5) * offsetScale
    implicitWidth: drop.active ? drop.depth : Tokens.sizes.sidebar.width
    clip: true // (the drop reveals the content; always on: toggling it left rounded masks black)
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
                    implicitWidth: Qt.binding(() => Tokens.sizes.sidebar.width - content.anchors.leftMargin - content.anchors.margins),
                    props: root.props,
                    screenState: root.screenState
                });
        }

        opacity: root.drop.contentOpacity
        // Where it sits: one expression each (never swapped anchors); with the drop, at its final
        // place and full height while the droplet grows over it
        x: anchors.leftMargin + (root.drop.active ? root.width - root.drop.fullDepth : 0)
        y: anchors.margins - root.dropInsetTop
        height: root.height + root.dropInsetTop + root.dropInsetBottom - anchors.margins
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
