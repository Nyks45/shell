pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Hover popout of a taskbar item: the app, and a live preview of each of its
// windows on that workspace. Click a preview to switch to it.
Item {
    id: root

    required property PopoutState popouts
    readonly property var app: {
        CUtils.dependency(Hypr.toplevels.values);
        return TaskbarApps.appsFor(popouts.taskbarWs, true).find(a => a.key === popouts.taskbarKey) ?? null;
    }
    readonly property string appName: app?.entry?.name ?? app?.cls ?? ""

    // The app went away (its last window closed, not pinned): close, rather
    // than show an empty popout.
    onAppChanged: {
        if (!app && popouts.currentName === "taskbar")
            popouts.hasCurrent = false;
    }

    // A window closed from here: the popout shrinks, and the pointer may now
    // rest outside it (nothing else closes it until the pointer moves). Once
    // the cards have settled, close unless it's on one of them.
    property bool closedFromHere
    readonly property int cardCount: app?.toplevels.length ?? 0
    onCardCountChanged: {
        if (closedFromHere)
            settleCheck.restart();
    }

    Timer {
        id: settleCheck

        interval: 250
        onTriggered: {
            root.closedFromHere = false;
            let onCard = false;
            for (let i = 0; i < cards.count; i++) {
                const c = cards.itemAt(i) as Preview;
                if (c?.pointerOn)
                    onCard = true;
            }
            if (!onCard && root.popouts.currentName === "taskbar")
                root.popouts.hasCurrent = false;
        }
    }

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        RowLayout {
            spacing: Tokens.spacing.small

            IconImage {
                implicitSize: Tokens.font.body.small.pointSize * 1.8
                asynchronous: true
                source: root.app?.entry?.icon ? Quickshell.iconPath(root.app.entry.icon, "application-x-executable") : Icons.getAppIcon(root.app?.cls ?? "", "application-x-executable")
            }

            StyledText {
                text: root.appName
                font: Tokens.font.body.small
            }
        }

        // A pinned app with no window here: open it.
        TextButton {
            visible: !!root.app && root.app.toplevels.length === 0 && !!root.app.entry
            text: qsTr("Open %1").arg(root.appName)
            onClicked: {
                TaskbarApps.launch(root.app);
                root.popouts.hasCurrent = false;
            }
        }

        Row {
            spacing: Tokens.spacing.small
            visible: (root.app?.toplevels.length ?? 0) > 0

            Repeater {
                id: cards

                model: ScriptModel {
                    values: root.app?.toplevels ?? []
                }

                Preview {}
            }
        }
    }

    component Preview: Item {
        id: card

        required property HyprlandToplevel modelData
        readonly property bool minimized: TaskbarApps.isMinimized(modelData)
        readonly property bool focused: modelData === Hyprland.activeToplevel && !minimized
        readonly property bool pointerOn: hover.containsMouse || closeBtn.hovered
        // The preview takes the window's shape within 150 x 96, but at least 84
        // wide: tall windows show their top part (cropped) instead of a sliver.
        readonly property real aspect: {
            const size = modelData.lastIpcObject.size ?? [16, 10];
            return Math.max(0.2, size[0] / Math.max(1, size[1]));
        }
        readonly property real previewW: Math.round(Math.max(84, Math.min(150, 96 * aspect)))
        readonly property real previewH: Math.round(Math.min(96, previewW / aspect))

        implicitWidth: previewW + Tokens.padding.small * 2
        implicitHeight: frame.implicitHeight + title.implicitHeight + Tokens.spacing.small + Tokens.padding.small * 2

        scale: hover.containsMouse || closeBtn.hovered ? 1.03 : 1
        opacity: 0
        Component.onCompleted: opacity = Qt.binding(() => card.minimized && !hover.containsMouse ? 0.75 : 1)

        Behavior on scale {
            Anim {}
        }
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.palette.m3secondaryContainer
            opacity: hover.containsMouse || closeBtn.hovered ? 0.6 : card.focused ? 0.35 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StateLayer {
            id: hover

            radius: Tokens.rounding.large
            onClicked: {
                TaskbarApps.hyprflow("activate", card.modelData);
                root.popouts.hasCurrent = false;
            }
        }

        ClippingWrapperRectangle {
            id: frame

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.small

            implicitWidth: card.previewW
            implicitHeight: card.previewH
            radius: Tokens.rounding.medium
            // Solid: translucent windows (terminals) would vanish into the
            // popout otherwise; on screen they show over something too.
            color: Colours.palette.m3surfaceContainerLowest

            Item {
                implicitWidth: card.previewW
                implicitHeight: card.previewH

                // Live while shown, scaled to the width and cropped at the bottom;
                // a minimized (hidden) window has nothing to capture: its icon.
                ScreencopyView {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !card.minimized
                    captureSource: card.minimized ? null : card.modelData.wayland
                    live: visible
                    constraintSize.width: card.previewW
                    constraintSize.height: card.previewW / card.aspect
                }

                // Minimized: the app's icon in grey on the tile, with a small
                // minimize mark in the corner.
                IconImage {
                    anchors.centerIn: parent
                    visible: card.minimized
                    implicitSize: Math.min(card.previewW, card.previewH) * 0.42
                    asynchronous: true
                    source: Icons.getAppIcon(card.modelData.lastIpcObject.class ?? "", "application-x-executable")
                    opacity: 0.7
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        saturation: -1
                    }
                }

                MaterialIcon {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.small
                    visible: card.minimized
                    text: "minimize"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                    opacity: 0.8
                }
            }
        }

        StyledText {
            id: title

            anchors.top: frame.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            horizontalAlignment: Text.AlignHCenter
            text: card.modelData.title
            font: Tokens.font.body.small
            elide: Text.ElideRight
            color: card.focused ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
        }

        // Close: a small round button on the preview's corner (like Windows'
        // thumbnails), shown on hover.
        StyledRect {
            id: closeBtn

            readonly property bool hovered: closeLayer.containsMouse

            // On the card's corner, half outside it: never over the preview.
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -implicitHeight / 3
            anchors.rightMargin: -implicitWidth / 3
            implicitWidth: closeIcon.implicitHeight + 4
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: hovered ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHighest
            opacity: hover.containsMouse || hovered ? 1 : 0
            scale: hover.containsMouse || hovered ? 1 : 0.7

            StateLayer {
                id: closeLayer

                radius: Tokens.rounding.full
                color: Colours.palette.m3onErrorContainer
                onClicked: {
                    root.closedFromHere = true;
                    TaskbarApps.close(card.modelData);
                }
            }

            MaterialIcon {
                id: closeIcon

                anchors.centerIn: parent
                text: "close"
                color: closeBtn.hovered ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.small
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
            Behavior on scale {
                Anim {}
            }
            Behavior on color {
                CAnim {}
            }
        }
    }
}
