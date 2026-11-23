pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.modules.drawers

// Floating glass popup panel anchored to a trigger control, matching Menu.qml's
// islands style, spring animation, and viewport-aware placement.
MouseArea {
    id: root

    required property Item attachTo
    property Item ownArea: attachTo
    property bool expanded
    property bool keepAsChild
    property real contentWidth: 220
    property real contentHeight: 160
    property real maxHeight: 280
    property Component content: null

    readonly property bool active: expanded || opacity > 0
    readonly property bool inDrawer: !!(QsWindow.window as ContentWindow)
    readonly property alias item: contentLoader.item

    parent: {
        if (root.keepAsChild)
            return root.attachTo;
        const win = QsWindow.window;
        if (!win)
            return root.attachTo;
        const contentWin = win as ContentWindow;
        return contentWin ? contentWin.interactionWrapper : (win as QsWindow).contentItem;
    }
    anchors.fill: parent
    z: 20

    enabled: expanded
    hoverEnabled: expanded
    cursorShape: expanded ? Qt.ArrowCursor : undefined

    onKeepAsChildChanged: if (keepAsChild)
        expanded = false
    onWheel: event => {
        root.expanded = false;
        event.accepted = true;
    }
    onPressed: mouse => {
        const p = ownArea ? ownArea.mapFromItem(root, mouse.x, mouse.y) : null;
        const onOwn = p && p.x >= 0 && p.y >= 0 && p.x < ownArea.width && p.y < ownArea.height;
        expanded = false;
        mouse.accepted = onOwn;
    }

    Connections {
        function onVisibleChanged(): void {
            if (!root.attachTo?.visible)
                root.expanded = false;
        }

        target: root.attachTo
    }

    Shortcut {
        enabled: root.expanded
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: root.expanded = false
    }

    opacity: expanded ? 1 : 0
    visible: opacity > 0 && parent !== attachTo
    // Only while fading (as Menu): not a hidden layer per closed popup
    layer.enabled: opacity > 0 && opacity < 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    TransformWatcher {
        id: watcher

        // Watched only while shown (as Menu)
        a: root.visible ? root.parent : null
        b: root.visible ? root.attachTo : null
    }

    Elevation {
        id: panel

        readonly property real edgePad: Tokens.padding.medium
        readonly property real gapY: Tokens.spacing.small
        readonly property real pad: Tokens.padding.small
        readonly property real parentW: root.parent ? root.parent.width : 0
        readonly property real parentH: root.parent ? root.parent.height : 0
        readonly property point anchorPos: {
            CUtils.dependency(watcher.transform);
            if (!root.parent || !root.attachTo || root.parent === root.attachTo)
                return Qt.point(0, 0);
            void root.expanded;
            return root.attachTo.mapToItem(root.parent, 0, 0);
        }
        readonly property real anchorW: root.attachTo ? root.attachTo.width : 0
        readonly property real anchorH: root.attachTo ? root.attachTo.height : 0
        readonly property real naturalW: Math.max(170, root.contentWidth + pad * 2)
        readonly property real naturalH: Math.min(root.maxHeight, Math.max(32, root.contentHeight) + pad * 2)
        readonly property real spaceBelow: parentH > 0 ? Math.max(0, parentH - edgePad - (anchorPos.y + anchorH + gapY)) : naturalH
        readonly property real spaceAbove: parentH > 0 ? Math.max(0, (anchorPos.y - gapY) - edgePad) : naturalH
        readonly property bool effectiveAbove: parentH > 0 && !(naturalH <= spaceBelow || spaceBelow >= spaceAbove)
        readonly property real maxW: parentW > 0 ? Math.max(140, parentW - edgePad * 2) : naturalW
        readonly property real maxH: {
            if (parentH <= 0)
                return naturalH;
            const sideSpace = effectiveAbove ? spaceAbove : spaceBelow;
            const viewportMax = Math.max(56, parentH - edgePad * 2);
            return Math.max(56, Math.min(viewportMax, sideSpace >= Math.min(naturalH, 120) ? sideSpace : viewportMax));
        }

        implicitWidth: Math.min(naturalW, maxW)
        implicitHeight: Math.min(naturalH, maxH)

        x: {
            const targetX = anchorPos.x + anchorW - width;
            return parentW > 0 ? CUtils.clamp(targetX, edgePad, Math.max(edgePad, parentW - edgePad - width)) : targetX;
        }
        y: {
            const rawY = effectiveAbove ? (anchorPos.y - gapY - height) : (anchorPos.y + anchorH + gapY);
            return parentH > 0 ? CUtils.clamp(rawY, edgePad, Math.max(edgePad, parentH - edgePad - height)) : rawY;
        }

        radius: Tokens.rounding.extraLarge
        level: 2

        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        transform: Scale {
            xScale: root.expanded ? 1 : 0.85
            yScale: root.expanded ? 1 : 0.7
            origin.x: panel.width
            origin.y: panel.effectiveAbove ? panel.height : 0

            Behavior on xScale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Behavior on yScale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onWheel: e => e.accepted = true
        }

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: root.inDrawer
                ? Colours.tPalette.m3surfaceContainer
                : (Colours.transparency.enabled ? Qt.alpha(Colours.palette.m3surfaceContainer, Math.max(Colours.transparency.base, 0.88)) : Colours.palette.m3surfaceContainer)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)

            Loader {
                id: contentLoader

                anchors.fill: parent
                anchors.margins: panel.pad
                active: root.active && !!root.content
                asynchronous: false
                sourceComponent: root.content
            }
        }
    }
}
