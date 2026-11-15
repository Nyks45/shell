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

    visible: offsetScale < 1
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): the panel expands out of
    // the edge like Nebula's media island (grows down and widens, its content revealed in place),
    // instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula" || GlobalConfig.appearance.style.shellAnim === "island"
    readonly property real openT: 1 - offsetScale

    anchors.topMargin: expandStyle ? 0 : (-implicitHeight - 5) * offsetScale
    implicitHeight: expandStyle ? content.implicitHeight * openT : content.implicitHeight
    implicitWidth: (content.implicitWidth || 854) * (expandStyle ? 0.3 + 0.7 * openT : 1) // 854: fallback for first open
    clip: true // (always: switching it on and off left the rounded-clip textures black)
    opacity: expandStyle ? 1 : 1 - offsetScale
    // (No fade on the content: it holds rounded masks that capture it into a texture, and Qt
    // doesn't capture anything at opacity 0, so they stayed black. Expanding reveals it in place.)

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

        anchors.horizontalCenter: parent.horizontalCenter
        // Where it sits: one x/y expression, never swapped anchors (swapping fixed its size at 0
        // after a style switch: an empty dashboard and notification list)
        // (expanding: stays put at the top and is revealed; sliding: moves with the panel's bottom)
        y: root.expandStyle ? 0 : parent.height - height

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
