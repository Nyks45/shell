pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

// The dashboard grows out of a small pill at the top edge and springs to full size, its
// contents scaling with it from the first frames (like DankMaterialShell's island). Closing is
// the same in reverse; a change of mind mid-way turns around smoothly (one spring).
Item {
    id: root

    required property ScreenState screenState

    readonly property real nonAnimHeight: (content.item as Item)?.nonAnimHeight ?? 0
    readonly property bool shouldBeActive: screenState.dashboard && Config.dashboard.enabled

    // 0 closed .. 1 open (may pass 1 by a hair while settling)
    readonly property real morph: spring.value
    // For the drawers that still read it (1 hidden .. 0 shown)
    readonly property real offsetScale: 1 - Math.min(1, Math.max(0, morph))

    readonly property real fullWidth: content.implicitWidth || 854 // Hard coded fallback for first open
    readonly property real fullHeight: content.implicitHeight
    // Where hovering the top edge opens it (and keeps it open): its full width, centred, even
    // while its shape is small or closed (drawers/Interactions.qml)
    readonly property real hoverWidth: fullWidth
    // The pill it grows from
    readonly property real pillWidth: Math.min(fullWidth, 240)

    visible: morph > 0.002 || shouldBeActive
    // (the pill itself narrows into the edge over the last fifth, so nothing lingers there)
    implicitWidth: visible ? pillWidth * Math.min(1, Math.max(0, morph) * 5) + (fullWidth - pillWidth) * morph : 0
    implicitHeight: Math.max(0, fullHeight * morph)

    SpringValue {
        id: spring

        target: root.shouldBeActive ? 1 : 0
    }

    Loader {
        id: content

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState
                });
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // Scaled with the shape, from its top edge; shown over the first third of the way
        transformOrigin: Item.Top
        scale: Math.max(0.01, Math.min(root.width / root.fullWidth, Math.max(0, root.morph)))
        opacity: Math.min(1, Math.max(0, root.morph / 0.35))

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
