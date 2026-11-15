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

    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula" || GlobalConfig.appearance.style.shellAnim === "island"
    readonly property real openT: 1 - offsetScale

    visible: offsetScale < 1
    anchors.rightMargin: expandStyle ? 0 : (-implicitWidth - 5) * offsetScale
    implicitWidth: Tokens.sizes.sidebar.width * (expandStyle ? openT : 1)
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
                    implicitWidth: Qt.binding(() => Tokens.sizes.sidebar.width - content.anchors.leftMargin - content.anchors.margins),
                    props: root.props,
                    screenState: root.screenState
                });
        }

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Where it sits: one x/y expression, never swapped anchors (swapping fixed its size at 0
        // after a style switch: an empty dashboard and notification list)
        // (at the panel's leading edge in every style: expanding, the body widens over it, so the
        // start of every line shows first instead of half-cut text)
        x: anchors.leftMargin
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)
        anchors.bottomMargin: 0

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
