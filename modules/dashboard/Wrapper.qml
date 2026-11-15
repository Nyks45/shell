pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState

    readonly property real nonAnimHeight: (content.item as Item)?.nonAnimHeight ?? 0
    readonly property bool shouldBeActive: screenState.dashboard && Config.dashboard.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): the panel expands out of
    // the edge like Nebula's media island (grows down and widens, its content revealed in place),
    // instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula"
    readonly property real openT: 1 - offsetScale

    anchors.topMargin: expandStyle ? 0 : (-implicitHeight - 5) * offsetScale
    implicitHeight: expandStyle ? content.implicitHeight * openT : content.implicitHeight
    implicitWidth: (content.implicitWidth || 854) * (expandStyle ? 0.3 + 0.7 * openT : 1) // 854: fallback for first open
    clip: expandStyle
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
        transformOrigin: Item.Top

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState
                });
        }

        anchors.horizontalCenter: parent.horizontalCenter
        // (expanding: the content stays put and is revealed; sliding: it moves with the panel)
        anchors.top: root.expandStyle ? parent.top : undefined
        anchors.bottom: root.expandStyle ? undefined : parent.bottom

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
