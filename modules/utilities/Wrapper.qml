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
    readonly property bool shouldBeActive: screenState.sidebar || (screenState.utilities && Config.utilities.enabled && !(screenState.session && Config.session.enabled))
    readonly property real totalPadding: content.anchors.margins + CUtils.clamp(content.anchors.margins - Config.border.thickness, 0, content.anchors.margins)
    readonly property real nonAnimHeight: ((content.item as Item)?.nonAnimHeight ?? 0) + totalPadding
    property real offsetScale: shouldBeActive ? 0 : 1
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula"
    readonly property real openT: 1 - offsetScale
    property real sidebarLerp

    visible: offsetScale < 1
    anchors.bottomMargin: expandStyle ? 0 : (-implicitHeight - 5) * offsetScale
    implicitHeight: (content.implicitHeight + totalPadding) * (expandStyle && !attached ? openT : 1)
    clip: expandStyle
    // Expanding with the sidebar: one body. Attached, it widens exactly with the sidebar (whose
    // width already grows) and doesn't grow on its own; its content keeps its final width and is
    // revealed from the right edge, not reflowed while the panel grows.
    readonly property real fullWidth: attached ? Tokens.sizes.sidebar.width * horizontalStretch : Tokens.sizes.utilities.width
    // (the sidebar on screen, opening or closing: its own transition doesn't matter then)
    readonly property bool attached: expandStyle && sidebar.offsetScale < 1
    implicitWidth: attached ? sidebar.width * horizontalStretch : expandStyle ? Tokens.sizes.utilities.width : sidebar.width * (1 - sidebar.offsetScale) * horizontalStretch * sidebarLerp + Tokens.sizes.utilities.width * (1 - sidebarLerp)
    opacity: expandStyle ? 1 : 1 - offsetScale
    // Expanding: the body grows first, then the content fades in and settles (closing: the
    // content goes first, then the body folds back into the edge)
    readonly property real contentT: !expandStyle ? 1 : attached ? sidebar.contentT : Math.max(0, Math.min(1, (openT - 0.35) / 0.6))

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
                    implicitWidth: Qt.binding(() => (root.expandStyle ? root.fullWidth : root.implicitWidth) - root.totalPadding),
                    props: root.props,
                    screenState: root.screenState,
                    popouts: root.popouts,
                    deformMatrix: Qt.binding(() => root.deformMatrix)
                });
        }

        // (expanding: stays put at the bottom edge and is revealed; sliding: moves with the panel)
        anchors.top: root.expandStyle ? undefined : parent.top
        anchors.bottom: root.expandStyle ? parent.bottom : undefined
        anchors.left: root.expandStyle ? undefined : parent.left
        anchors.right: root.expandStyle ? parent.right : undefined
        anchors.margins: Tokens.padding.large

        asynchronous: true
        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
