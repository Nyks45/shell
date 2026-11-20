pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.modules.drawers

MouseArea {
    id: root

    enum Side {
        Top,
        Bottom,
        Left,
        Right
    }

    required property Item attachTo
    // What opened the menu (a press there only closes it); the attach point by default
    property Item ownArea: attachTo
    property int attachSideX: Menu.Right
    property int attachSideY: Menu.Bottom
    property int thisSideX: Menu.Right
    property int thisSideY: Menu.Top
    property real marginX
    property real marginY

    property list<MenuItem> items
    property MenuItem active: items[0] ?? null
    property bool expanded
    readonly property bool inDrawer: !!(QsWindow.window as ContentWindow)

    signal itemSelected(item: MenuItem)

    parent: {
        const win = QsWindow.window;
        if (!win)
            return root.attachTo;
        const contentWin = win as ContentWindow; // If inside the drawer content window, put it inside the interaction wrapper so hover works
        return contentWin ? contentWin.interactionWrapper : (win as QsWindow).contentItem;
    }
    anchors.fill: parent
    z: 20

    enabled: expanded
    hoverEnabled: expanded
    cursorShape: expanded ? Qt.ArrowCursor : undefined
    onWheel: event => {
        root.expanded = false;
        event.accepted = true;
    }
    onExpandedChanged: if (expanded)
        menuFlick.contentY = 0
    // A press outside closes the menu and goes on to what's under it: another
    // menu's button or a row works with that one click, not a second one
    // (A press on the menu's own button just closes it: passed on, the button
    // would open it again.)
    onPressed: mouse => {
        const p = ownArea ? ownArea.mapFromItem(root, mouse.x, mouse.y) : null;
        const onOwnButton = p && p.x >= 0 && p.y >= 0 && p.x < ownArea.width && p.y < ownArea.height;
        expanded = false;
        mouse.accepted = onOwnButton;
    }

    Connections {
        function onVisibleChanged(): void {
            if (!root.attachTo?.visible)
                root.expanded = false;
        }

        target: root.attachTo
    }

    opacity: expanded ? 1 : 0
    // Gone once faded out: closed, the menu is only scaled down (to 10%), and a
    // long one still covered the rows under its button and took their clicks
    visible: opacity > 0
    layer.enabled: opacity < 1

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    TransformWatcher {
        id: watcher

        a: root.parent
        b: root.attachTo
    }

    Elevation {
        id: menu

        readonly property real edgePad: Tokens.padding.medium
        readonly property real parentW: root.parent ? root.parent.width : 0
        readonly property real parentH: root.parent ? root.parent.height : 0
        readonly property point anchorPos: {
            CUtils.dependency(watcher.transform); // mapToItem is not reactive so this forces updates
            if (!root.parent || !root.attachTo || root.parent === root.attachTo)
                return Qt.point(0, 0);
            void root.expanded;
            return root.attachTo.mapToItem(root.parent, 0, 0);
        }
        readonly property real anchorW: root.attachTo ? root.attachTo.width : 0
        readonly property real anchorH: root.attachTo ? root.attachTo.height : 0
        readonly property real naturalW: Math.max(170, column.implicitWidth + Tokens.padding.small * 2)
        readonly property real naturalH: column.implicitHeight + Tokens.padding.small * 2

        readonly property bool isDropdownY: root.attachSideY !== root.thisSideY
        readonly property real gapY: Math.abs(root.marginY)
        readonly property real spaceBelow: {
            if (parentH <= 0)
                return naturalH;
            if (isDropdownY)
                return parentH - edgePad - (anchorPos.y + anchorH + gapY);
            const edgeY = anchorPos.y + (root.attachSideY === Menu.Top ? 0 : anchorH) + root.marginY;
            return parentH - edgePad - edgeY;
        }
        readonly property real spaceAbove: {
            if (parentH <= 0)
                return naturalH;
            if (isDropdownY)
                return (anchorPos.y - gapY) - edgePad;
            const edgeY = anchorPos.y + (root.attachSideY === Menu.Top ? 0 : anchorH) + root.marginY;
            return edgeY - edgePad;
        }
        readonly property bool preferAbove: isDropdownY ? (root.attachSideY === Menu.Top && root.thisSideY === Menu.Bottom) : (root.thisSideY === Menu.Bottom)
        readonly property bool effectiveAbove: {
            if (parentH <= 0)
                return preferAbove;
            if (preferAbove)
                return naturalH <= spaceAbove || spaceAbove >= spaceBelow;
            return !(naturalH <= spaceBelow || spaceBelow >= spaceAbove);
        }

        readonly property real maxW: parentW > 0 ? Math.max(120, parentW - edgePad * 2) : naturalW
        readonly property real maxH: {
            if (parentH <= 0)
                return naturalH;
            const sideSpace = effectiveAbove ? spaceAbove : spaceBelow;
            const viewportMax = Math.max(48, parentH - edgePad * 2);
            return Math.max(48, Math.min(viewportMax, sideSpace >= Math.min(naturalH, 160) ? sideSpace : viewportMax));
        }

        implicitWidth: Math.min(naturalW, maxW)
        implicitHeight: Math.min(naturalH, maxH)

        readonly property real rawX: {
            const edgeX = anchorPos.x + (root.attachSideX === Menu.Left ? 0 : anchorW) + root.marginX;
            return root.thisSideX === Menu.Right ? (edgeX - width) : edgeX;
        }
        readonly property real flippedX: {
            const flippedAttach = root.attachSideX === Menu.Left ? Menu.Right : Menu.Left;
            const flippedThis = root.thisSideX === Menu.Right ? Menu.Left : Menu.Right;
            const edgeX = anchorPos.x + (flippedAttach === Menu.Left ? 0 : anchorW) - root.marginX;
            return flippedThis === Menu.Right ? (edgeX - width) : edgeX;
        }
        readonly property bool alignRightDesired: root.thisSideX === Menu.Right
        readonly property bool effectiveAlignRight: {
            if (parentW <= 0)
                return alignRightDesired;
            const overflows = rawX < edgePad || (rawX + width) > (parentW - edgePad);
            if (!overflows)
                return alignRightDesired;
            const flipFits = flippedX >= edgePad && (flippedX + width) <= (parentW - edgePad);
            return flipFits ? !alignRightDesired : alignRightDesired;
        }

        x: {
            const targetX = effectiveAlignRight !== alignRightDesired ? flippedX : rawX;
            return parentW > 0 ? CUtils.clamp(targetX, edgePad, Math.max(edgePad, parentW - edgePad - width)) : targetX;
        }
        y: {
            const rawY = isDropdownY
                ? (effectiveAbove ? (anchorPos.y - gapY - height) : (anchorPos.y + anchorH + gapY))
                : ((anchorPos.y + (root.attachSideY === Menu.Top ? 0 : anchorH) + root.marginY) - (effectiveAbove ? height : 0));
            return parentH > 0 ? CUtils.clamp(rawY, edgePad, Math.max(edgePad, parentH - edgePad - height)) : rawY;
        }

        // In the islands' style: glass with a soft edge, opening from the corner it's attached
        // to (scale and fade, on the islands' spring)
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
            origin.x: menu.effectiveAlignRight ? menu.width : 0
            origin.y: menu.effectiveAbove ? menu.height : 0

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

            Flickable {
                id: menuFlick

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                contentWidth: width
                contentHeight: column.implicitHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: column

                    width: menuFlick.width
                    spacing: 2

                    Repeater {
                        id: repeater

                        model: root.items

                        StyledRect {
                            id: item

                            required property int index
                            required property MenuItem modelData
                            readonly property bool active: modelData === root?.active

                            Layout.fillWidth: true
                            // compact rows
                            implicitWidth: menuOptionRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: menuOptionRow.implicitHeight + Tokens.padding.small * 2

                            // Rows are pills
                            radius: height / 2

                            color: Qt.alpha(Colours.palette.m3secondaryContainer, active ? 1 : 0)

                            Behavior on radius {
                                Anim {}
                            }

                            StateLayer {
                                topLeftRadius: parent.topLeftRadius
                                topRightRadius: parent.topRightRadius
                                bottomLeftRadius: parent.bottomLeftRadius
                                bottomRightRadius: parent.bottomRightRadius

                                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                disabled: !root.expanded
                                onClicked: {
                                    root.itemSelected(item.modelData);
                                    root.active = item.modelData;
                                    item.modelData.clicked();
                                    root.expanded = false;
                                }
                            }

                            RowLayout {
                                id: menuOptionRow

                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.medium
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: item.modelData?.icon ?? ""
                                    fontStyle: Tokens.font.icon.small
                                    color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: item.modelData?.text ?? ""
                                    font: Tokens.font.body.small
                                    color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                }

                                Loader {
                                    asynchronous: true
                                    Layout.alignment: Qt.AlignVCenter
                                    active: item.modelData?.trailingIcon.length > 0
                                    visible: active

                                    sourceComponent: MaterialIcon {
                                        text: item.modelData.trailingIcon
                                        color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
