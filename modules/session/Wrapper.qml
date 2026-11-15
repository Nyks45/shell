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
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula" || GlobalConfig.appearance.style.shellAnim === "island"
    readonly property real openT: 1 - offsetScale
    property real sidebarOffset: sidebarVisible ? 14 : 0

    visible: offsetScale < 1
    anchors.rightMargin: expandStyle ? 0 : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: content.implicitWidth * (expandStyle ? openT : 1)
    clip: true // (always: switching it on and off left the rounded-clip textures black)
    implicitHeight: content.implicitHeight || 510 // Hard coded fallback for first open
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

        anchors.verticalCenter: parent.verticalCenter
        // Where it sits: one x/y expression, never swapped anchors (swapping fixed its size at 0
        // after a style switch: an empty dashboard and notification list)
        // (expanding: stays put at the right edge and is revealed; sliding: moves with the panel)
        x: 0

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
