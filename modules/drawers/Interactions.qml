import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property ScreenState screenState
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool osdShortcutActive

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.borderThickness + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.implicitWidth + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panel.x) && withinPanelHeight(panel, x, y);
    }

    // On the dashboard's pill (its shape while it peeks out of the top edge)
    function onDashboardPill(x: real, y: real): bool {
        const panel = panels.dashboard;
        const centre = bar.implicitWidth + panel.x + panel.width / 2;
        return panel.width > 0 && Math.abs(x - centre) <= panel.width / 2 && y < Config.border.thickness + panel.floatGap + panel.height;
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        // A panel can give its own hover strip (the dashboard: its full width, centred, while
        // its shape is small or closed), else its shape's
        const hoverWidth = panel.hoverWidth; // qmllint disable missing-property
        if (hoverWidth !== undefined) {
            const centre = bar.implicitWidth + panel.x + panel.width / 2;
            const inWidth = Math.abs(x - centre) <= hoverWidth / 2 + Config.border.rounding;
            return inWidth && y < Math.max(Config.border.minThickness, Config.border.thickness + (panel.floatGap ?? 0) + (panel.hoverHeight ?? panel.height)); // qmllint disable missing-property
        }
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y < Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y > height - Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (event.x < bar.implicitWidth) {
            bar.handleWheel(event.y, event.angleDelta);
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide if not activated by shortcut
            if (!osdShortcutActive && !screenState.osdExpanded) {
                screenState.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive && !screenState.dashboardSticky)
                screenState.dashboard = false;
            panels.dashboard.peeking = false;

            if (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    // A window being dragged (hyprflow): the screen edges are for snapping it,
    // so nothing hidden there opens meanwhile, and what was open from hovering
    // closes.
    Connections {
        function onWindowDraggingChanged(): void {
            if (!Hypr.windowDragging)
                return;
            if (!root.dashboardShortcutActive && !root.screenState.dashboardSticky)
                root.screenState.dashboard = false;
            root.panels.dashboard.peeking = false;
            if (!root.osdShortcutActive && !root.screenState.osdExpanded) {
                root.screenState.osd = false;
                root.panels.osd.hovered = false;
            }
            if (Config.launcher.showOnHover)
                root.screenState.launcher = false;
            if (Config.bar.showOnHover)
                root.bar.isHovered = false;
            root.popouts.hasCurrent = false;
        }

        target: Hypr
    }

    onPositionChanged: event => {
        if (Hypr.windowDragging)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen) {
            root.panels.osd.hovered = inRightPanel(panels.osdWrapper, x, y);
            return;
        }

        // The pill (centred) comes out from the middle part of the left edge (its corners are
        // for other things) ...
        if (!screenState.bar && Config.bar.showOnHover && x < bar.clampedWidth && (bar.isHovered || (y > height * 0.15 && y < height * 0.85)))
            bar.isHovered = true;
        // ... and goes once the pointer leaves both that part and the pill itself along the edge
        // (towards a corner), unless one of its menus is open
        if (bar.isHovered && !screenState.bar && x < bar.clampedWidth && !popouts.hasCurrent && (y < height * 0.15 || y > height * 0.85) && (y < bar.pillTop - Tokens.padding.large || y > bar.pillBottom + Tokens.padding.large))
            bar.isHovered = false;

        // Show/hide bar on drag
        if (pressed && dragStart.x < bar.clampedWidth) {
            if (dragX > Config.bar.dragThreshold)
                screenState.bar = true;
            else if (dragX < -Config.bar.dragThreshold)
                screenState.bar = false;
        }

        // The volume and brightness island: shown while the pointer is on its part of the right
        // edge (or on it)
        const showOsd = inRightPanel(panels.osdWrapper, x, y);
        if (!osdShortcutActive && !screenState.osdExpanded) {
            screenState.osd = showOsd;
            root.panels.osd.hovered = showOsd;
        } else if (showOsd) {
            // If hovering over OSD area while in shortcut mode, transition to hover control
            osdShortcutActive = false;
            root.panels.osd.hovered = true;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inBottomPanel(panels.launcher, x, y))
                screenState.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                screenState.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                screenState.launcher = false;
        }

        // The dashboard on hover: the top edge brings out its pill (the time); resting on the
        // pill opens it (dashboard/Wrapper.qml); leaving the area hides both
        const showDashboard = Config.dashboard.showOnHover && inTopPanel(panels.dashboard, x, y);
        panels.dashboard.peeking = showDashboard;

        if (!dashboardShortcutActive) {
            if (!showDashboard && !screenState.dashboardSticky)
                screenState.dashboard = false;
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && Math.abs(x - (bar.implicitWidth + panels.dashboard.x + panels.dashboard.width / 2)) <= panels.dashboard.hoverWidth / 2 + Config.border.rounding) {
            if (dragY > Config.dashboard.dragThreshold)
                screenState.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                screenState.dashboard = false;
        }

        // Show popouts on hover (not while a window is dragged over the bar)
        if (x < bar.implicitWidth && !Hypr.windowDragging) {
            bar.checkPopout(y);
        } else if ((!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inLeftPanel(panels.popoutsWrapper, x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    // A window dragged over the bar: no hover popouts (and close an open one).
    Connections {
        function onWindowDraggingChanged(): void {
            if (Hypr.windowDragging)
                root.popouts.hasCurrent = false;
        }

        target: Hypr
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and OSD
            if (!root.screenState.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.screenState.dashboard = false;
                }
                if (!inOsdArea && !root.screenState.osdExpanded) {
                    root.screenState.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.screenState.dashboard) {
                // Dashboard became visible, immediately check if this should be shortcut mode
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.dashboardShortcutActive = true;
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.dashboardShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (root.screenState.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        target: root.screenState
    }
}
