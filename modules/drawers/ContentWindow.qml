pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar

StyledWindow {
    id: root

    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions

    readonly property ScreenState screenState: ShellState.forScreen(screen)

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool hasSpecialWorkspace: (monitor?.lastIpcObject.specialWorkspace?.name.length ?? 0) > 0
    readonly property bool hasFullscreenOnNormalWs: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return hasFullscreenOnNormalWs;
    }

    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
    readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
    readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness

    property color surfaceColour: Colours.tPalette.m3surface
    // The islands (dashboard, pill, its menus): lighter glass than the panels, more of the blurred
    // picture behind showing through (their cards keep their own tint, so text stays readable)
    readonly property color islandColour: Qt.alpha(Colours.palette.m3surface, Math.min(root.surfaceColour.a, 0.6))

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace?.toplevels.values.length > 0)
            return 0;

        // Desktop icons on the empty desktop: the wider drag area would cover
        // (and take the clicks of) the ones near the edges
        if (contentItem.Config.background.desktopIcons)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        screenState.launcher = false;
        screenState.session = false;
        screenState.dashboard = false;
        panels.popouts.close();
    }

    name: "drawers"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: (fsTransitionProg > 0 && contentItem.Config.general.showOverFullscreen) || (hasSpecialWorkspace && hasFullscreenOnNormalWs) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: screenState.launcher || screenState.session || (screenState.dashboard && screenState.dashboardSticky) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: hasFullscreen ? emptyRegion : regions

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on fsTransitionProg {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    Region {
        id: emptyRegion

        x: panels.notifications.x + bar.implicitWidth
        y: panels.notifications.y + root.borderThickness
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: root.width - width
            y: panels.osdWrapper.y + root.borderThickness
            width: panels.osdWrapper.width * (1 - panels.osd.offsetScale) + root.borderThickness
            height: panels.osd.height
        }
    }

    Regions {
        id: regions

        bar: bar
        panels: panels
        win: root
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: {
            const s = root.screenState;
            const conf = root.contentItem.Config;
            if (!s || !conf) // the screen went away (shell reload, monitor unplugged)
                return false;
            if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))
                return true;
            if (!conf.dashboard.showOnHover && s.dashboard && conf.dashboard.enabled)
                return true;
            if (s.dashboard && s.dashboardSticky)
                return true;
            if (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)
                return true;
            return false;
        }
        windows: [root]
        onCleared: {
            root.screenState.launcher = false;
            root.screenState.session = false;
            root.screenState.sidebar = false;
            root.screenState.dashboard = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: (root.screenState.session && Config.session.enabled && !root.screenState.sessionAtBar) || panels.popouts.detachedMode !== "" ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.surfaceColour.a
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        // The islands' own groups: drawn like the panels, never melted into the frame or into
        // each other (the dashboard island; the pill bar; its menus)
        BlobGroup {
            id: islandGroup

            color: root.islandColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        BlobGroup {
            id: pillGroup

            color: root.islandColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        BlobGroup {
            id: popoutIslandGroup

            color: root.islandColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        BlobGroup {
            id: blobGroup

            color: root.surfaceColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        // The frame around the screen (its rounded corners): none with the floating pill bar,
        // where everything is an island of its own
        BlobInvertedRect {
            visible: !bar.pill
            anchors.fill: parent
            anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
            group: blobGroup
            radius: root.borderRounding
            // (with the pill bar, the frame's left edge is as thin as the others: the pill is
            // its own shape below)
            borderLeft: (bar.pill ? root.borderThickness : bar.implicitWidth) - anchors.margins - root.sdfBorderOffset
            borderRight: root.borderThickness - anchors.margins - root.sdfBorderOffset
            borderTop: root.borderThickness - anchors.margins - root.sdfBorderOffset
            borderBottom: root.borderThickness - anchors.margins - root.sdfBorderOffset
        }

        PanelBg {
            id: dashBg

            // An island: its own shape, not melted into the frame
            group: islandGroup
            panel: panels.dashboard
            deformAmount: 0.1
            radius: Math.min(Tokens.rounding.extraLarge, height / 2)

            IslandEdge {}
        }

        PanelBg {
            id: launcherBg

            // With the pill bar: an island (glass, apart from the edge)
            group: bar.pill ? islandGroup : blobGroup
            visible: !bar.pill || panels.launcher.width > 1
            panel: panels.launcher
            deformAmount: 0.1
            radius: bar.pill ? Math.min(Tokens.rounding.extraLarge, height / 2) : Tokens.rounding.extraLarge

            IslandEdge {
                visible: bar.pill
            }
        }

        PanelBg {
            id: sessionBg

            panel: panels.sessionWrapper
            deformAmount: 0.2
            x: panels.sessionWrapper.x + panels.session.x + bar.implicitWidth
            implicitWidth: panels.session.width
        }

        PanelBg {
            id: sidebarBg

            panel: panels.sidebar
            deformAmount: 0.03
            implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [utilsBg]
            bottomLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: osdBg

            group: bar.pill ? islandGroup : blobGroup
            visible: !bar.pill || panels.osd.width > 1
            panel: panels.osdWrapper
            deformAmount: 0.25
            x: panels.osdWrapper.x + panels.osd.x + bar.implicitWidth
            y: panels.osdWrapper.y + panels.osd.y + root.borderThickness
            implicitWidth: panels.osd.width
            implicitHeight: panels.osd.height
            radius: bar.pill ? Math.min(Tokens.rounding.extraLarge, width / 2) : Tokens.rounding.extraLarge

            IslandEdge {
                visible: bar.pill
            }
        }

        // The bar as a pill (Config.bar.pill): an island of its own on the left edge
        BlobRect {
            readonly property real fullH: Math.max(0, bar.pillBottom - bar.pillTop)
            readonly property real r: Math.min(1, Math.max(0, bar.reveal))
            // grows in place from its centre, like the top island out of its pill
            // (a small capsule growing into the pill, not a thin stick)
            // (and over the last bit it shrinks away to nothing: no sliver left behind)
            readonly property real tail: Math.min(1, r / 0.25)
            readonly property real growW: (0.45 + 0.55 * r) * tail
            readonly property real growH: (0.45 + 0.55 * r) * tail

            visible: bar.pill && bar.reveal > 0.002
            group: pillGroup
            x: bar.pillX + bar.contentWidth * (1 - growW) / 2
            y: bar.pillTop + fullH * (1 - growH) / 2
            implicitWidth: bar.contentWidth * growW
            implicitHeight: fullH * growH
            radius: width / 2

            IslandEdge {}
        }

        // The incoming notifications have no panel behind them: each is its own card
        // (notifications/Notification.qml); this shape stays empty, for the deform transform
        PanelBg {
            id: notifsBg

            group: null
            visible: false
            panel: panels.notifications
        }

        PanelBg {
            id: utilsBg

            panel: panels.utilities
            deformAmount: panels.sidebar.visible ? 0.1 : 0.15
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
            topLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: popoutBg

            // Extra width to prevent vertical movement deformation partially detaching panel from bar
            property real extraWidth: panels.popouts.isDetached || bar.pill ? 0 : 0.2

            // With the pill bar: an island of its own (glass like the top's), apart from the edge
            group: bar.pill && !panels.popouts.isDetached ? popoutIslandGroup : blobGroup
            // (closed, its sliver would melt into whatever is next to it)
            visible: !bar.pill || (panels.popoutsWrapper.width > 1 && (!fromPill || m > 0.01))
            panel: panels.popoutsWrapper
            deformAmount: panels.popouts.isDetached ? 0.05 : panels.popouts.hasCurrent ? 0.15 : 0.1

            // With the pill: grows out of the hovered icon (a small capsule on the pill) to its
            // place a gap away, and shrinks back into it
            readonly property bool fromPill: bar.pill && !panels.popouts.isDetached
            readonly property real m: Math.min(1, Math.max(0, panels.popoutsWrapper.morph))
            // The start capsule itself shrinks away over the last bit (nothing left on the icon)
            readonly property real tail: Math.min(1, m / 0.2)
            readonly property real startW: bar.contentWidth * 0.6 * tail
            readonly property real startH: 40 * tail
            readonly property real startX: bar.pillX + (bar.contentWidth - startW) / 2
            readonly property real startY: panels.popouts.currentCenter - startH / 2
            readonly property real endX: panels.popoutsWrapper.x + bar.implicitWidth
            readonly property real endY: panels.popoutsWrapper.y + root.borderThickness

            x: fromPill ? startX + (endX - startX) * m : panels.popoutsWrapper.x + panels.popouts.x + bar.implicitWidth - panels.popouts.width * extraWidth
            y: fromPill ? startY + (endY - startY) * m : panels.popoutsWrapper.y + root.borderThickness
            implicitWidth: fromPill ? startW + (panels.popoutsWrapper.width - startW) * m : panels.popouts.width * (1 + extraWidth)
            implicitHeight: fromPill ? startH + (panels.popoutsWrapper.height - startH) * m : panels.popoutsWrapper.height

            IslandEdge {
                visible: parent.fromPill
            }

            Behavior on extraWidth {
                Anim {}
            }
        }
    }

    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        screenState: root.screenState
        panels: panels
        bar: bar
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen

        Panels {
            id: panels

            screen: root.screen
            screenState: root.screenState
            bar: bar
            borderThickness: root.borderThickness

            utilities.horizontalStretch: (sidebarBg.rawDeformMatrix.m11 - 1) / 2 + 1
            utilities.deformMatrix: utilsBg.rawDeformMatrix

            dashboard.transform: Matrix4x4 {
                matrix: dashBg.deformMatrix
            }
            launcher.transform: Matrix4x4 {
                matrix: launcherBg.deformMatrix
            }
            session.transform: Matrix4x4 {
                matrix: sessionBg.deformMatrix
            }
            sidebar.transform: Matrix4x4 {
                matrix: sidebarBg.deformMatrix
            }
            osd.transform: Matrix4x4 {
                matrix: osdBg.deformMatrix
            }
            notifications.transform: Matrix4x4 {
                matrix: notifsBg.deformMatrix
            }
            utilities.transform: Matrix4x4 {
                matrix: utilsBg.deformMatrix
            }
            popouts.transform: Matrix4x4 {
                matrix: popoutBg.deformMatrix
            }
        }

        BarWrapper {
            id: bar

            anchors.top: parent.top
            anchors.bottom: parent.bottom

            screen: root.screen
            screenState: root.screenState
            popouts: panels.popouts

            fullscreen: root.hasFullscreen
        }
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "rootWindow"
        component: root
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "interactionWrapper"
        component: interactions
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "bar"
        component: bar
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "panels"
        component: panels
    }

    // An island's glass edge (like the settings window's): a soft 1px rim and a faint light
    // across its top
    component IslandEdge: Item {
        anchors.fill: parent
        visible: parent.visible && parent.width > 4

        Rectangle {
            anchors.fill: parent
            radius: (parent.parent as BlobRect)?.radius ?? 0
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, ((parent.parent as BlobRect)?.radius ?? 0) - 1)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.025)
                }
                GradientStop {
                    position: 0.35
                    color: "transparent"
                }
            }
        }
    }

    component PanelBg: BlobRect {
        required property Item panel
        property real deformAmount: 0.15

        group: blobGroup
        x: panel.x + bar.implicitWidth
        y: panel.y + root.borderThickness
        implicitWidth: panel.width
        implicitHeight: panel.height
        radius: Tokens.rounding.extraLarge
        deformScale: (deformAmount * Config.appearance.deformScale) / 10000
    }
}
