pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.modules.sidebar as Sidebar
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ScreenState screenState
    required property Sidebar.Wrapper sidebar
    required property BarPopouts.Wrapper popouts
    property real horizontalStretch
    property matrix4x4 deformMatrix

    readonly property PersistentProperties props: PersistentProperties {
        property bool recordingListExpanded: false
        property string recordingConfirmDelete
        property string recordingMode

        reloadableId: "utilities"
    }
    // Opens by itself only (not with the notifications sidebar); when both are open it sits under it
    readonly property bool shouldBeActive: screenState.utilities && Config.utilities.enabled && !(screenState.session && Config.session.enabled)
    readonly property real totalPadding: content.anchors.margins + CUtils.clamp(content.anchors.margins - Config.border.thickness, 0, content.anchors.margins)
    readonly property real nonAnimHeight: ((content.item as Item)?.nonAnimHeight ?? 0) + totalPadding
    property real offsetScale: 1
    property real sidebarLerp

    // Its own width (under the sidebar: the sidebar's)
    readonly property real normalWidth: sidebar.width * (1 - sidebar.offsetScale) * horizontalStretch * sidebarLerp + Tokens.sizes.utilities.width * (1 - sidebarLerp)
    // Wave motion: rises and spreads from where it was opened (components/WaveMotion.qml)
    readonly property WaveMotion drop: WaveMotion {
        panel: root
        screenState: root.screenState
        edge: "bottom"
        fullAlong: root.normalWidth
        fullDepth: root.content.implicitHeight + root.totalPadding
        finalCenter: (root.parent?.width ?? 0) - root.normalWidth / 2
        offsetScale: root.offsetScale
        open: root.shouldBeActive
    }
    readonly property real dropRadius: drop.radius
    readonly property alias content: content

    visible: offsetScale < 1
    anchors.bottomMargin: drop.active ? 0 : (-implicitHeight - 5) * offsetScale
    // (right-anchored: the drop's shift along the edge as a margin)
    anchors.rightMargin: drop.active ? Math.max(0, (drop.fullAlong - drop.along) / 2 - drop.offset) : 0
    implicitHeight: drop.active ? drop.depth : content.implicitHeight + totalPadding
    implicitWidth: drop.active ? drop.along : normalWidth
    clip: true // (the drop reveals the content; always on: toggling it left rounded masks black)
    opacity: drop.active ? 1 : 1 - offsetScale

    states: State {
        name: "attachedToSidebar"
        when: root.screenState.sidebar

        PropertyChanges {
            root.sidebarLerp: 1
        }
    }

    transitions: [
        Transition {
            from: ""

            Anim {
                property: "sidebarLerp"
                duration: Tokens.anim.durations.expressiveDefaultSpatial / 2
                easing: Tokens.anim.standardAccel
            }
        },
        Transition {
            to: ""

            Anim {
                property: "sidebarLerp"
                duration: Tokens.anim.durations.expressiveDefaultSpatial / 2
                easing: Tokens.anim.standardDecel
            }
        }
    ]

    ShellMotion {
        target: root
        to: root.shouldBeActive ? 0 : 1
    }

    Loader {
        id: content

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    implicitWidth: Qt.binding(() => (root.drop.active ? root.normalWidth : root.implicitWidth) - root.totalPadding),
                    props: root.props,
                    screenState: root.screenState,
                    popouts: root.popouts,
                    deformMatrix: Qt.binding(() => root.deformMatrix)
                });
        }

        opacity: root.drop.contentOpacity
        // Where it sits: one expression each (never swapped anchors); with the drop, at its final
        // place while the wave grows over it
        readonly property real m: Tokens.padding.large
        anchors.margins: m // (read by totalPadding)
        x: m + (root.drop.active ? root.width + root.anchors.rightMargin - root.drop.fullAlong : 0)
        y: m + (root.drop.active ? root.height - root.drop.fullDepth : 0)

        asynchronous: true
        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
