pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar
import qs.services

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    x: bar.clampedWidth + win.dragMaskPadding
    y: clampedThickness + win.dragMaskPadding
    width: win.width - bar.clampedWidth - clampedThickness - win.dragMaskPadding * 2
    height: win.height - clampedThickness * 2 - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    // The dashboard island: from the edge down through its gap to its shape; its full size while
    // it opens (the pointer can run ahead of it)
    R {
        readonly property real w: root.panels.dashboard.shouldBeActive ? Math.max(panel.width, panel.hoverWidth) : panel.width

        panel: root.panels.dashboard
        x: root.bar.implicitWidth + panel.x + panel.width / 2 - w / 2
        y: 0
        width: w
        height: panel.floatGap + panel.hoverHeight + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.borderThickness
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    // The taskbar's right-click menu: everything takes input while it's open.
    // (Closed, it's parked off the window: an empty region would count as all
    // of it.)
    Region {
        x: TaskbarApps.menuOpen ? root.x : -10
        y: TaskbarApps.menuOpen ? root.y : -10
        width: TaskbarApps.menuOpen ? root.width : 1
        height: TaskbarApps.menuOpen ? root.height : 1
        intersection: Intersection.Subtract
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.implicitWidth
        y: panel.y + root.borderThickness
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
