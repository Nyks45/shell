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

    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula" || GlobalConfig.appearance.style.shellAnim === "island"
    readonly property real openT: 1 - offsetScale
    property real closingHeight

    // Switching style while running: back to the live height (a close may have fixed it)
    // Switching style while running: back to the live height (a close may have fixed it)
    onExpandStyleChanged: implicitHeight = Qt.binding(() => content.implicitHeight * (expandStyle ? openT : 1))

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight * (expandStyle ? openT : 1));
        else if (expandStyle) {
            // the height it had, shrinking (its content can change size while closing)
            closingHeight = content.implicitHeight;
            implicitHeight = Qt.binding(() => closingHeight * openT);
        } else
            implicitHeight = implicitHeight; // Break binding during close anim
    }

    visible: offsetScale < 1
    anchors.bottomMargin: expandStyle ? 0 : (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight * (expandStyle ? openT : 1)
    implicitWidth: (content.implicitWidth || 630) * (expandStyle ? 0.3 + 0.7 * openT : 1) // 630: fallback for first open
    clip: true // (always: switching it on and off left the rounded-clip textures black)
    opacity: expandStyle ? 1 : 1 - offsetScale
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
        y: 0
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
