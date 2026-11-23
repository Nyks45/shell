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

    // (the left edge takes no clicks of its own: only the pill's shape and its hover strip below)
    readonly property real edge: Math.max(clampedThickness, win.dragMaskPadding)

    x: edge
    y: clampedThickness + win.dragMaskPadding
    width: win.width - edge - clampedThickness - win.dragMaskPadding
    height: win.height - clampedThickness * 2 - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    // Where the pill comes out: a thin strip in the middle of the left edge (as Interactions
    // reveals it), always
    Region {
        x: 0
        y: root.win.height * 0.15
        width: root.win.contentItem.Config.border.minThickness
        height: root.win.height * 0.7
        intersection: Intersection.Subtract
    }

    // The pill itself, as big as it's drawn at the moment (it grows from its middle), with the
    // edge beside it; with one of its menus open, the gap to that menu too, along the menu's height
    Region {
        readonly property real fullH: Math.max(0, root.bar.pillBottom - root.bar.pillTop)
        readonly property real r: Math.min(1, Math.max(0, root.bar.reveal))
        readonly property real grow: (0.45 + 0.55 * r) * Math.min(1, r / 0.25)
        readonly property bool menu: root.panels.popouts.hasCurrent && root.panels.popoutsWrapper.width > 1
        readonly property real menuTop: root.panels.popoutsWrapper.y + root.borderThickness
        readonly property real menuBottom: menuTop + root.panels.popoutsWrapper.height
        readonly property real top: root.bar.pillTop + fullH * (1 - grow) / 2
        readonly property real bottom: top + fullH * grow

        x: 0
        y: menu ? Math.min(top, menuTop) : top
        width: root.bar.reveal > 0.002 ? (menu ? root.bar.implicitWidth : root.bar.pillX + root.bar.contentWidth * (0.5 + grow / 2)) : 0
        height: root.bar.reveal > 0.002 ? (menu ? Math.max(bottom, menuBottom) : bottom) - y : 0
        intersection: Intersection.Subtract
    }

    // The dashboard island: from the edge down through its gap to its shape; its full size while
    // it opens (the pointer can run ahead of it)
    R {
        readonly property real w: panel.width > 0 ? Math.max(panel.width, panel.hoverWidth) : 0

        panel: root.panels.dashboard
        x: root.bar.implicitWidth + panel.x + panel.width / 2 - w / 2
        y: 0
        width: w
        height: panel.floatGap + panel.hoverHeight + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        // (the centred styles: just the island)
        y: root.panels.launcher.centred ? panel.y + root.borderThickness : root.win.height - height
        height: root.panels.launcher.centred ? panel.height : panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    // The taskbar's right-click menu: everything takes input while it's open.
    // (Closed, it's parked off the window: an empty region would count as all
    // of it.)
    Region {
        readonly property bool fullInput: TaskbarApps.menuOpen || (root.win.openMenus ?? 0) > 0

        x: fullInput ? root.x : -10
        y: fullInput ? root.y : -10
        width: fullInput ? root.width : 1
        height: fullInput ? root.height : 1
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
