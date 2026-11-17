pragma ComponentBehavior: Bound

import QtQuick
import "Reveal.js" as Reveal
import Caelestia.Config
import qs.components
import qs.services

// The dashboard as a hiding island: touching the top edge brings out a small pill with the time
// and date and a button per page (two rows a side); a button opens that page alone, clicking
// the time and date or the shortcut the overview (hovering only shows the pill). Moving away shrinks it
// back into the edge. The shortcut opens the dashboard at once. It grows like Nebula's media island: the shape eases
// out over about half a second, revealing the page at full size, which fades in near the end.
Item {
    id: root

    required property ScreenState screenState

    // Set by the drawers (drawers/Interactions.qml): the pointer is at the top edge / on the pill
    property bool peeking
    // The pointer is on the pill itself (its buttons included)
    readonly property bool pointerOnPill: pillHover.hovered && morph < 0.05

    readonly property real nonAnimHeight: (content.item as Item)?.nonAnimHeight ?? 0
    readonly property bool dashEnabled: Config.dashboard.enabled
    readonly property bool shouldBeActive: screenState.dashboard && dashEnabled

    // 0 closed .. 1 open (may pass 1 by a hair while settling)
    readonly property real morph: spring.value
    // 0 hidden .. 1 the pill
    // 0 hidden .. 1 the pill: runs at a steady pace (the reveal's own timing shapes it), and
    // closing plays it backwards
    property real peek: (peeking || shouldBeActive) && dashEnabled ? 1 : 0

    Behavior on peek {
        SmoothedAnimation {
            velocity: 2.0
            maximumEasingTime: 0
            reversingMode: SmoothedAnimation.Immediate
        }
    }
    // For the drawers that still read it (1 hidden .. 0 shown)
    readonly property real offsetScale: 1 - Math.min(1, Math.max(0, morph))

    readonly property real fullWidth: content.implicitWidth || 854 // Hard coded fallback for first open
    readonly property real fullHeight: content.implicitHeight
    // Where hovering the top edge brings out the pill (and keeps it, and the dashboard, out): its
    // full width, centred, even while its shape is small or closed (drawers/Interactions.qml)
    readonly property real hoverWidth: fullWidth
    // and as tall as it's going to be (the pointer can run ahead of it while it grows)
    // (the pill's settings tab under it counts too)
    readonly property real hoverHeight: shouldBeActive ? Math.max(height, fullHeight) : height + (peek > 0.05 ? settingsTab.height + settingsTab.anchors.topMargin : 0)
    // It floats this far below the top edge, as an island (its shape stays apart from the frame)
    readonly property real floatGap: Tokens.spacing.medium
    // The pill: the time, with buttons that open one page alone either side
    readonly property real pillWidth: Math.min(fullWidth, face.implicitWidth + Tokens.padding.medium * 2)
    readonly property real pillHeight: face.implicitHeight + Tokens.padding.small * 2

    // The reveal, a contained overload: a circle with a comet spinning up in its ring, the ring
    // heating and shaking, then a flash inside, a shockwave pushing the pill's sides out, sparks
    // bouncing off its rim; closing, the same backwards (Reveal.js has the timeline)
    readonly property var rv: Reveal.at(peek, pillHeight, pillWidth)
    readonly property real peekWidth: rv.width
    readonly property real peekHeight: rv.height

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
            key: "notifications",
            icon: "notifications",
            on: true
        },
        {
            key: "quick",
            icon: "tune",
            on: true
        },
        {
            key: "wallpapers",
            icon: "wallpaper",
            on: Config.dashboard.showWallpapers
        },
        {
            key: "settings",
            icon: "settings",
            on: true
        },
        {
            key: "power",
            icon: "power_settings_new",
            on: true
        }
    ].filter(p => p.on)
    // The pill keeps to what's reached for most (the other pages are a tab away inside): the
    // notifications and media left of the time, the quick settings and power right of it
    readonly property var pillLeft: ["notifications", "media"].map(k => pages.find(p => p.key === k)).filter(p => !!p)
    readonly property var pillRight: ["quick", "power"].map(k => pages.find(p => p.key === k)).filter(p => !!p)

    // One page alone, at once
    function openPage(key: string): void {
        const i = pages.findIndex(p => p.key === key);
        if (i < 0)
            return;
        screenState.dashboardTab = i;
        screenState.dashboardSolo = true;
        screenState.dashboardSticky = key === "settings";
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

    // A click on the pill's time: the quick settings
    function openNotifications(): void {
        openPage("quick");
    }

    // The island replaces the old edge panels: asked for (shortcuts, IPC),
    // they open its page instead (the notifications sidebar, the quick toggles, the power menu)
    Connections {
        function onSidebarChanged(): void {
            if (root.screenState.sidebar) {
                root.screenState.sidebar = false;
                root.openPage("notifications");
            }
        }

        function onUtilitiesChanged(): void {
            if (root.screenState.utilities) {
                root.screenState.utilities = false;
                root.openPage("quick");
            }
        }

        function onSessionChanged(): void {
            if (root.screenState.session) {
                root.screenState.session = false;
                root.openPage("power");
            }
        }

        target: root.screenState
    }

    // Another page asked for from inside the island (the quick settings' "open in settings")
    Connections {
        function onDashboardRequestChanged(): void {
            if (root.screenState.dashboardRequest === "")
                return;
            root.openPage(root.screenState.dashboardRequest);
            root.screenState.dashboardRequest = "";
        }

        target: root.screenState
    }

    // Closed: the next opening picks its page again
    onMorphChanged: {
        if (morph < 0.002 && !shouldBeActive && screenState.dashboardSolo) {
            screenState.dashboardSolo = false;
            screenState.dashboardSticky = false;
        }
    }

    visible: morph > 0.002 || peek > 0.002 || shouldBeActive || peeking
    // The page is revealed by the growing shape (not scaled with it)
    implicitWidth: visible ? peekWidth + (fullWidth - peekWidth) * morph : 0
    implicitHeight: Math.max(0, peekHeight + (fullHeight - peekHeight) * morph)

    // The opening: like Nebula's media island, about half a second, slowing to a stop with no
    // bounce (a spring just past critical, so turning around mid-way stays smooth)
    HoverHandler {
        id: pillHover
    }

    SpringValue {
        id: spring

        stiffness: 170
        damping: 27
        target: root.shouldBeActive ? 1 : 0
    }



    // The reveal's light: the ring and its comet, the flash, the shockwave and the sparks, drawn
    // inside the pill's shape
    Canvas {
        id: revealFx

        anchors.fill: parent
        visible: root.peek > 0.001 && root.peek < 0.999 && root.morph < 0.2
        opacity: 1 - Math.min(1, root.morph * 5)
        onPaint: Reveal.paint(getContext("2d"), width, height, root.peek, root.pillHeight, root.pillWidth)

        Connections {
            function onPeekChanged(): void {
                if (revealFx.visible)
                    revealFx.requestPaint();
            }

            target: root
        }
    }

    // The pill's face: page buttons, the time, page buttons
    Row {
        id: face

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium
        opacity: Math.max(0, root.rv.face - root.morph * 5)
        scale: 0.9 + 0.1 * root.rv.face
        visible: opacity > 0.01

        Grid {
            anchors.verticalCenter: parent.verticalCenter
            rows: 1
            columnSpacing: Tokens.spacing.small

            Repeater {
                model: root.pillLeft

                PillButton {}
            }
        }

        // The time and date: a click opens the notifications and quick settings
        StyledRect {
            id: clock

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: clockRow.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: clockRow.implicitHeight + Tokens.padding.extraSmall
            radius: height / 2
            color: "transparent"

            StateLayer {
                onClicked: root.openAll()
            }

            Column {
                id: clockRow

                anchors.centerIn: parent
                spacing: -2

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.timeStr.replace(/:(AM|PM)$/i, " $1")
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.format("ddd d MMM")
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        Grid {
            anchors.verticalCenter: parent.verticalCenter
            rows: 1
            columnSpacing: Tokens.spacing.small

            Repeater {
                model: root.pillRight

                PillButton {}
            }
        }
    }

    // The settings: a small tab hanging under the pill's clock (a gear and an arrow down), shown
    // with the pill; a click grows the island into the settings
    StyledRect {
        id: settingsTab

        readonly property real showT: root.rv.face * Math.max(0, 1 - root.morph * 8)

        anchors.top: parent.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: tabRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: tabRow.implicitHeight + 6
        radius: height / 2
        color: tabLayer.containsMouse ? Colours.palette.m3primaryContainer : Qt.alpha(Colours.palette.m3surface, 0.6)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        visible: showT > 0.01
        opacity: showT
        transform: Translate {
            y: -8 * (1 - settingsTab.showT)
        }

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            id: tabLayer

            radius: settingsTab.height / 2
            color: Colours.palette.m3onPrimaryContainer
            onClicked: root.openPage("settings")
        }

        Row {
            id: tabRow

            anchors.centerIn: parent
            spacing: 2

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "settings"
                color: tabLayer.containsMouse ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "keyboard_arrow_down"
                color: tabLayer.containsMouse ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    component PillButton: StyledRect {
        id: btn

        required property var modelData

        // (placed by its grid)
        implicitWidth: 30
        implicitHeight: 30
        radius: height / 2
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        // The notifications button shows when there are some: a filled bell in the accent
        // colour and a count badge on its corner
        readonly property int unread: btn.modelData.key === "notifications" ? Notifs.notClosed.length : 0

        StateLayer {
            onClicked: root.openPage(btn.modelData.key)
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.unread > 0 ? "notifications_unread" : btn.modelData.icon
            color: btn.unread > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
            fill: btn.unread > 0 ? 1 : 0
        }

        StyledRect {
            visible: btn.unread > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -3
            anchors.rightMargin: -4
            implicitWidth: Math.max(implicitHeight, countText.implicitWidth + 8)
            implicitHeight: 15
            radius: implicitHeight / 2
            color: Colours.palette.m3primary
            border.width: 2
            border.color: Qt.alpha(Colours.palette.m3surface, 0.9)

            StyledText {
                id: countText

                anchors.centerIn: parent
                text: btn.unread > 99 ? "99+" : btn.unread
                color: Colours.palette.m3onPrimary
                font.family: Tokens.font.label.small.family
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }
    }

    // The page, revealed by the growing shape
    Item {
        anchors.fill: parent
        clip: true

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

}
