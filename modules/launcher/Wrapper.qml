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

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    // The list style: an island floating a gap above the bottom edge, grown out of a small
    // capsule there (like the top island out of its pill), the search bar first
    readonly property real floatGap: Tokens.spacing.medium
    readonly property real open: 1 - offsetScale
    // (over the last bit the capsule itself shrinks away: nothing left on the edge)
    readonly property real tail: Math.min(1, open / 0.2)
    readonly property real capW: 180
    readonly property real capH: 44
    property real fullHeight: content.implicitHeight

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            fullHeight = Qt.binding(() => content.implicitHeight);
        else
            fullHeight = fullHeight; // Break binding during close anim
    }

    readonly property real fullWidth: content.implicitWidth || 630 // Hard coded fallback for first open

    // The centred styles (Config.launcher.style), each opening its own way:
    //  "grid": zooms in from the middle (the island and its contents together), the icons
    //          coming in row by row
    //  "wallpaper": opens like a book out of its wallpaper, the search and list sliding out
    //          from under it
    // (the old list at the bottom edge is gone: the grid unless the wallpaper one is chosen)
    readonly property string style: Config.launcher.style === "wallpaper" ? "wallpaper" : "grid"
    readonly property bool centred: style === "grid" || style === "wallpaper"
    readonly property real zoom: 0.8 + 0.2 * open
    readonly property real bookWidth: (content.item as CentreContent)?.collapsedWidth ?? 320
    // (the book opens fast at first, then settles)
    readonly property real bookOpen: 1 - Math.pow(1 - open, 2)

    visible: offsetScale < 1
    anchors.bottomMargin: centred ? 0 : floatGap
    implicitHeight: style === "grid" ? fullHeight * zoom * tail : style === "wallpaper" ? fullHeight * (0.88 + 0.12 * open) * tail : (capH + (fullHeight - capH) * open) * tail
    implicitWidth: style === "grid" ? fullWidth * zoom * tail : style === "wallpaper" ? (bookWidth + (fullWidth - bookWidth) * bookOpen) * tail : (capW + (fullWidth - capW) * open) * tail
    clip: true
    // (the island's contents fade in once it has grown enough to hold them; the book's
    // wallpaper shows from the start)
    opacity: style === "grid" ? Math.min(1, Math.max(0, (open - 0.03) / 0.3)) : style === "wallpaper" ? Math.min(1, open / 0.3) : Math.min(1, Math.max(0, (open - 0.35) / 0.5))

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

        function ensureSource(): void {
            if (!active || source.toString())
                return;
            const props = {
                screenState: root.screenState,
                panels: root.panels,
                maxHeight: Qt.binding(() => root.maxHeight)
            };
            if (root.centred)
                props.open = Qt.binding(() => root.open);
            setSource(Qt.resolvedUrl(root.centred ? "CentreContent.qml" : "Content.qml"), props);
        }

        // (the island reveals it from the bottom: the search bar first; the grid zooms with its
        // island, from the middle; the book opens from its left, the wallpaper)
        anchors.bottom: root.centred ? undefined : parent.bottom
        anchors.verticalCenter: root.centred ? parent.verticalCenter : undefined
        anchors.horizontalCenter: root.style === "wallpaper" ? undefined : parent.horizontalCenter
        anchors.left: root.style === "wallpaper" ? parent.left : undefined
        // (the grid's contents zoom with its island, to nothing at the end)
        // (the book's wallpaper shrinks away with it at the end, towards its left)
        scale: root.style === "grid" ? root.zoom * root.tail : root.style === "wallpaper" ? root.tail : 1
        transformOrigin: root.style === "wallpaper" ? Item.Left : Item.Center

        active: root.shouldBeActive || root.visible
        onActiveChanged: ensureSource()
        Component.onCompleted: ensureSource()
    }

    // Another style chosen: its contents next time it opens
    onStyleChanged: {
        content.source = "";
        content.ensureSource();
    }
}
