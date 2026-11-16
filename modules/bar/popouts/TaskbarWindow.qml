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
    readonly property string appName: app?.entry?.name || app?.cls || (app?.toplevels[0]?.title ?? "")

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

    implicitWidth: column.implicitWidth + Tokens.padding.small * 2
    implicitHeight: column.implicitHeight + Tokens.padding.small * 2

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        // The app: its icon on a tile, its name and how many windows, and what to do with it
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 40
                implicitHeight: 40
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 26
                    asynchronous: true
                    source: root.app?.entry?.icon ? Quickshell.iconPath(root.app.entry.icon, "application-x-executable") : Icons.getAppIcon(root.app?.cls ?? "", "application-x-executable")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: root.appName
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.cardCount === 0 ? qsTr("Not running") : root.cardCount === 1 ? qsTr("1 window") : qsTr("%1 windows").arg(root.cardCount)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }

            Item {
                Layout.fillWidth: true
                implicitWidth: Tokens.spacing.large
            }

            IconButton {
                visible: !!root.app?.entry
                type: IconButton.Text
                icon: root.cardCount ? "add" : "play_arrow"
                onClicked: {
                    TaskbarApps.launch(root.app);
                    root.popouts.hasCurrent = false;
                }
            }

            IconButton {
                visible: !!root.app?.key
                type: IconButton.Text
                icon: "keep"
                label.fill: TaskbarApps.isPinned(root.app?.key ?? "") ? 1 : 0
                onClicked: TaskbarApps.isPinned(root.app.key) ? TaskbarApps.unpin(root.app.key) : TaskbarApps.pin(root.app.key)
            }

            IconButton {
                visible: root.cardCount > 1
                type: IconButton.Text
                icon: "close_small"
                onClicked: {
                    root.closedFromHere = true;
                    for (const t of (root.app?.toplevels ?? []).slice())
                        TaskbarApps.close(t);
                }
            }
        }

        Row {
            spacing: Tokens.spacing.small
            visible: root.cardCount > 0

            Repeater {
                id: cards

                model: ScriptModel {
                    values: root.app?.toplevels ?? []
                }

                Preview {}
            }
        }
    }

    // A window: its live picture with the title over its foot; the focused one ringed
    component Preview: Item {
        id: card

        required property HyprlandToplevel modelData
        readonly property bool minimized: TaskbarApps.isMinimized(modelData)
        readonly property bool focused: modelData === Hyprland.activeToplevel && !minimized
        readonly property bool pointerOn: hover.containsMouse || closeBtn.hovered
        readonly property real aspect: {
            const size = modelData.lastIpcObject.size ?? [16, 10];
            return Math.max(0.2, size[0] / Math.max(1, size[1]));
        }
        readonly property real previewW: Math.round(Math.max(120, Math.min(220, 130 * aspect)))
        readonly property real previewH: Math.round(Math.min(130, previewW / aspect))

        implicitWidth: previewW
        implicitHeight: previewH

        // (no growing on hover: it would run into its neighbour; the ring shows it)
        opacity: 0
        Component.onCompleted: opacity = 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        ClippingWrapperRectangle {
            id: frame

            anchors.fill: parent
            radius: Tokens.rounding.large
            // Solid: translucent windows (terminals) would vanish into the card otherwise
            color: Colours.palette.m3surfaceContainerLowest

            Item {
                // Live while shown, scaled to the width and cropped at the bottom; a minimized
                // window has nothing to capture: its icon
                ScreencopyView {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !card.minimized
                    captureSource: card.minimized ? null : card.modelData.wayland
                    live: visible
                    constraintSize.width: card.previewW
                    constraintSize.height: card.previewW / card.aspect
                }

                IconImage {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -8
                    visible: card.minimized
                    implicitSize: Math.min(card.previewW, card.previewH) * 0.38
                    asynchronous: true
                    source: Icons.getAppIcon(card.modelData.lastIpcObject.class ?? "", "application-x-executable")
                    opacity: 0.6
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        saturation: -1
                    }
                }

                // The title over the foot of the picture
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: titleRow.implicitHeight + Tokens.padding.small * 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.45
                            color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.85)
                        }
                    }

                    RowLayout {
                        id: titleRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        StyledRect {
                            visible: card.minimized
                            implicitWidth: minLabel.implicitWidth + 8
                            implicitHeight: minLabel.implicitHeight + 2
                            radius: height / 2
                            color: Colours.palette.m3secondaryContainer

                            StyledText {
                                id: minLabel

                                anchors.centerIn: parent
                                text: qsTr("Minimized")
                                color: Colours.palette.m3onSecondaryContainer
                                font: Tokens.font.label.small
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.title
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // The focused window's ring
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Tokens.rounding.large + 3
            color: "transparent"
            border.width: 2
            border.color: card.focused ? Colours.palette.m3primary : card.pointerOn ? Qt.alpha(Colours.palette.m3primary, 0.5) : "transparent"

            Behavior on border.color {
                CAnim {}
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

        // Close: a round button inside the top right corner, on hover
        StyledRect {
            id: closeBtn

            readonly property bool hovered: closeLayer.containsMouse

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: hovered ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.9)
            opacity: card.pointerOn ? 1 : 0
            scale: card.pointerOn ? 1 : 0.7

            StateLayer {
                id: closeLayer

                radius: 13
                color: Colours.palette.m3onError
                onClicked: {
                    root.closedFromHere = true;
                    TaskbarApps.close(card.modelData);
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "close"
                color: closeBtn.hovered ? Colours.palette.m3onError : Colours.palette.m3onSurface
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
