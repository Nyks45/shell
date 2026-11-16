pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The dashboard as a hiding island: touching the top edge brings out a small pill with the time
// and a button per page; a button opens that page alone; resting the pointer on the pill (1.5 s),
// clicking the time or the shortcut opens the overview page alone (there are no tabs). Moving away shrinks it
// back into the edge. The shortcut opens the dashboard at once. It grows like Nebula's media island: the shape eases
// out over about half a second, revealing the page at full size, which fades in near the end.
Item {
    id: root

    required property ScreenState screenState

    // Set by the drawers (drawers/Interactions.qml): the pointer is at the top edge / on the pill
    property bool peeking
    property bool pointerOnPill

    readonly property real nonAnimHeight: (content.item as Item)?.nonAnimHeight ?? 0
    readonly property bool dashEnabled: Config.dashboard.enabled
    readonly property bool shouldBeActive: screenState.dashboard && dashEnabled

    // 0 closed .. 1 open (may pass 1 by a hair while settling)
    readonly property real morph: spring.value
    // 0 hidden .. 1 the pill
    readonly property real peek: peekSpring.value
    // For the drawers that still read it (1 hidden .. 0 shown)
    readonly property real offsetScale: 1 - Math.min(1, Math.max(0, morph))

    readonly property real fullWidth: content.implicitWidth || 854 // Hard coded fallback for first open
    readonly property real fullHeight: content.implicitHeight
    // Where hovering the top edge brings out the pill (and keeps it, and the dashboard, out): its
    // full width, centred, even while its shape is small or closed (drawers/Interactions.qml)
    readonly property real hoverWidth: fullWidth
    // and as tall as it's going to be (the pointer can run ahead of it while it grows)
    readonly property real hoverHeight: shouldBeActive ? Math.max(height, fullHeight) : height
    // It floats this far below the top edge, as an island (its shape stays apart from the frame)
    readonly property real floatGap: Tokens.spacing.medium
    // The pill: the time, with buttons that open one page alone either side
    readonly property real pillWidth: Math.min(fullWidth, face.implicitWidth + Tokens.padding.medium * 2)
    readonly property real pillHeight: face.implicitHeight + Tokens.padding.small * 2

    // The pages (as the dashboard lists them: its tab order, the ones turned on)
    readonly property var pages: [
        {
            key: "dashboard",
            icon: "dashboard",
            on: Config.dashboard.showDashboard
        },
        {
            key: "media",
            icon: "queue_music",
            on: Config.dashboard.showMedia
        },
        {
            key: "performance",
            icon: "speed",
            on: Config.dashboard.showPerformance
        },
        {
            key: "weather",
            icon: "cloud",
            on: Config.dashboard.showWeather
        },
        {
            key: "wallpapers",
            icon: "wallpaper",
            on: Config.dashboard.showWallpapers
        }
    ].filter(p => p.on)
    readonly property var pillButtons: pages.filter(p => p.key !== "dashboard")

    // One page alone, at once
    function openPage(key: string): void {
        const i = pages.findIndex(p => p.key === key);
        if (i < 0)
            return;
        screenState.dashboardTab = i;
        screenState.dashboardSolo = true;
        screenState.dashboard = true;
    }

    // The overview page (the first page shown when it's turned off)
    function openAll(): void {
        openPage(pages.some(p => p.key === "dashboard") ? "dashboard" : (pages[0]?.key ?? ""));
    }

    // Opened some other way (the shortcut): the overview page, alone too
    onShouldBeActiveChanged: {
        if (shouldBeActive && !screenState.dashboardSolo) {
            const i = pages.findIndex(p => p.key === "dashboard");
            screenState.dashboardTab = Math.max(0, i);
            screenState.dashboardSolo = true;
        }
    }

    // Closed: the next opening picks its page again
    onMorphChanged: {
        if (morph < 0.002 && !shouldBeActive && screenState.dashboardSolo)
            screenState.dashboardSolo = false;
    }

    visible: morph > 0.002 || peek > 0.002 || shouldBeActive || peeking
    // The page is revealed by the growing shape (not scaled with it)
    clip: true
    implicitWidth: visible ? pillWidth * Math.max(0, peek) + (fullWidth - pillWidth * Math.max(0, peek)) * morph : 0
    implicitHeight: Math.max(0, pillHeight * Math.max(0, peek) + (fullHeight - pillHeight * Math.max(0, peek)) * morph)

    // The opening: like Nebula's media island, about half a second, slowing to a stop with no
    // bounce (a spring just past critical, so turning around mid-way stays smooth)
    SpringValue {
        id: spring

        stiffness: 170
        damping: 27
        target: root.shouldBeActive ? 1 : 0
    }

    SpringValue {
        id: peekSpring

        target: (root.peeking || root.shouldBeActive) && root.dashEnabled ? 1 : 0
    }

    // Resting on the pill opens the dashboard
    Timer {
        interval: 1500
        running: root.peeking && root.pointerOnPill && !root.shouldBeActive && root.dashEnabled
        onTriggered: root.openAll()
    }

    // The pill's face: page buttons, the time, page buttons
    Row {
        id: face

        anchors.centerIn: parent
        spacing: Tokens.spacing.small
        opacity: Math.max(0, Math.min(1, root.peek) - root.morph * 5)
        scale: 0.6 + 0.4 * Math.max(0, Math.min(1, root.peek))
        visible: opacity > 0.01

        Repeater {
            model: root.pillButtons.slice(0, Math.ceil(root.pillButtons.length / 2))

            PillButton {}
        }

        StyledText {
            id: clock

            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Tokens.padding.small
            rightPadding: Tokens.padding.small
            text: Time.timeStr.replace(/:(AM|PM)$/i, " $1")
            font: Tokens.font.title.medium
            color: Colours.palette.m3onSurface

            // The time opens the whole dashboard
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openAll()
            }
        }

        Repeater {
            model: root.pillButtons.slice(Math.ceil(root.pillButtons.length / 2))

            PillButton {}
        }
    }

    component PillButton: StyledRect {
        id: btn

        required property var modelData

        anchors.verticalCenter: parent?.verticalCenter
        implicitWidth: 30
        implicitHeight: 30
        radius: height / 2
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        StateLayer {
            onClicked: root.openPage(btn.modelData.key)
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.modelData.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }
    }

    Loader {
        id: content

        function ensureSource(): void {
            if (active && !source.toString())
                setSource(Qt.resolvedUrl("Content.qml"), {
                    screenState: root.screenState
                });
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // At full size, revealed by the growing shape; fades in over the last part of the way
        // (Nebula's media island)
        opacity: Math.min(1, Math.max(0, (root.morph - 0.4) / 0.45))
        visible: root.morph > 0.002

        active: root.shouldBeActive || root.morph > 0.002 || root.peeking
        onActiveChanged: ensureSource()
        onLoaded: item.animateSize = Qt.binding(() => root.morph > 0.98 && root.shouldBeActive)
        Component.onCompleted: ensureSource()
    }
}
