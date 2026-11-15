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
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula" || GlobalConfig.appearance.style.shellAnim === "island"
    readonly property real openT: 1 - offsetScale
    property real sidebarLerp

    visible: offsetScale < 1
    anchors.bottomMargin: expandStyle ? 0 : (-implicitHeight - 5) * offsetScale
    implicitHeight: (content.implicitHeight + totalPadding) * (expandStyle ? openT : 1)
    clip: true // (always: switching it on and off left the rounded-clip textures black)
    // Expanding with the sidebar: one body. Attached, it widens exactly with the sidebar (whose
    // width already grows) and doesn't grow on its own; its content keeps its final width and is
    // revealed from the right edge, not reflowed while the panel grows.
    readonly property real fullWidth: attached ? Tokens.sizes.sidebar.width * horizontalStretch : Tokens.sizes.utilities.width
    // (the sidebar on screen, opening or closing: its own transition doesn't matter then)
    // (it opens on its own now: attached only while it is actually open with the sidebar)
    readonly property bool attached: expandStyle && shouldBeActive && sidebar.offsetScale < 1
    implicitWidth: attached ? sidebar.width * horizontalStretch : expandStyle ? Tokens.sizes.utilities.width : sidebar.width * (1 - sidebar.offsetScale) * horizontalStretch * sidebarLerp + Tokens.sizes.utilities.width * (1 - sidebarLerp)
    opacity: expandStyle ? 1 : 1 - offsetScale
    // (No fade on the content: it holds rounded masks that capture it into a texture, and Qt
    // doesn't capture anything at opacity 0, so they stayed black. Expanding reveals it in place.)

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
                    implicitWidth: Qt.binding(() => (root.expandStyle ? root.fullWidth : root.implicitWidth) - root.totalPadding),
                    props: root.props,
                    screenState: root.screenState,
                    popouts: root.popouts,
                    deformMatrix: Qt.binding(() => root.deformMatrix)
                });
        }

        // Where it sits: one x/y expression, never swapped anchors (swapping fixed its size at 0
        // after a style switch: an empty dashboard and notification list)
        // (expanding: stays put at the bottom right and is revealed; sliding: moves with the panel)
        readonly property real m: Tokens.padding.large
        anchors.margins: m // (read by totalPadding)
        x: m
        y: m

        asynchronous: true
        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }
}
