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

    property real offsetScale: shouldBeActive ? 0 : 1

    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula"
    readonly property real openT: 1 - offsetScale
    property real closingHeight

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
    implicitHeight: content.implicitHeight
    implicitWidth: (content.implicitWidth || 630) * (expandStyle ? 0.3 + 0.7 * openT : 1) // 630: fallback for first open
    clip: expandStyle
    opacity: expandStyle ? 1 : 1 - offsetScale
    // Expanding: the body grows first, then the content fades in and settles (closing: the
    // content goes first, then the body folds back into the edge)
    readonly property real contentT: expandStyle ? Math.max(0, Math.min(1, (openT - 0.35) / 0.6)) : 1

    Timer {
        interval: 300
        running: true
        onTriggered: Apps
    }

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        opacity: root.contentT
        scale: 0.96 + 0.04 * root.contentT
        transformOrigin: Item.Bottom

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState,
                    panels: root.panels,
                    maxHeight: Qt.binding(() => root.maxHeight)
                });
        }

        // (expanding: stays put at the bottom edge and is revealed; sliding: moves with the panel)
        anchors.top: root.expandStyle ? undefined : parent.top
        anchors.bottom: root.expandStyle ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
