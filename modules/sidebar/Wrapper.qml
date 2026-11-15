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
    property real offsetScale: shouldBeActive ? 0 : 1

    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula"
    readonly property real openT: 1 - offsetScale

    visible: offsetScale < 1
    anchors.rightMargin: expandStyle ? 0 : (-implicitWidth - 5) * offsetScale
    implicitWidth: Tokens.sizes.sidebar.width * (expandStyle ? openT : 1)
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
        transformOrigin: Item.Right

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    implicitWidth: Qt.binding(() => Tokens.sizes.sidebar.width - content.anchors.leftMargin - content.anchors.margins),
                    props: root.props,
                    screenState: root.screenState
                });
        }

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // (expanding: stays put at the right edge and is revealed; sliding: moves with the panel)
        anchors.left: root.expandStyle ? undefined : parent.left
        anchors.right: root.expandStyle ? parent.right : undefined
        anchors.rightMargin: anchors.margins
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)
        anchors.bottomMargin: 0

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
