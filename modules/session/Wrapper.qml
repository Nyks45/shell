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
    property real offsetScale: shouldBeActive ? 0 : 1
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula"
    readonly property real openT: 1 - offsetScale
    property real sidebarOffset: sidebarVisible ? 14 : 0

    visible: offsetScale < 1
    anchors.rightMargin: expandStyle ? 0 : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: content.implicitWidth * (expandStyle ? openT : 1)
    clip: expandStyle
    implicitHeight: content.implicitHeight || 510 // Hard coded fallback for first open
    opacity: expandStyle ? 1 : 1 - offsetScale
    // Expanding: the body grows first, then the content fades in and settles (closing: the
    // content goes first, then the body folds back into the edge)
    readonly property real contentT: expandStyle ? Math.max(0, Math.min(1, (openT - 0.35) / 0.6)) : 1

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        opacity: root.contentT
        scale: 0.96 + 0.04 * root.contentT
        transformOrigin: Item.Right

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState
                });
        }

        anchors.verticalCenter: parent.verticalCenter
        // (expanding: stays put at the right edge and is revealed; sliding: moves with the panel)
        anchors.left: root.expandStyle ? undefined : parent.left
        anchors.right: root.expandStyle ? parent.right : undefined

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
