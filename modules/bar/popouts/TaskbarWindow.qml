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
import qs.components.effects
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

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        // The app on one line: its icon, name and window count, its actions grouped on the right
        // (as wide as its previews: the name gives way, never empty space beside them)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: root.cardCount > 0 ? Math.max(cardsRow.implicitWidth - Tokens.padding.extraSmall, actionsCapsule.implicitWidth + 80) : -1
            Layout.leftMargin: Tokens.padding.extraSmall
            spacing: Tokens.spacing.small

            ThemedIcon {
                implicitSize: 20
                asynchronous: true
                source: root.app?.entry?.icon ? Quickshell.iconPath(root.app.entry.icon, "application-x-executable") : Icons.getAppIcon(root.app?.cls ?? "", "application-x-executable")
            }

            StyledText {
                text: root.appName
                font: Tokens.font.label.large
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.maximumWidth: 220
            }

            StyledRect {
                visible: root.cardCount > 1
                implicitWidth: countLabel.implicitWidth + 10
                implicitHeight: countLabel.implicitHeight + 2
                radius: height / 2
                color: Colours.palette.m3secondaryContainer

                StyledText {
                    id: countLabel

                    anchors.centerIn: parent
                    text: root.cardCount
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.label.small
                }
            }

            // The actions, small, in one capsule
            StyledRect {
                id: actionsCapsule

                implicitWidth: actions.implicitWidth + 4
                implicitHeight: actions.implicitHeight + 4
                radius: height / 2
                color: Colours.tPalette.m3surfaceContainerHigh

                Row {
                    id: actions

                    anchors.centerIn: parent
                    spacing: 0

                    SmallAction {
                        visible: !!root.app?.entry
                        icon: root.cardCount ? "add" : "play_arrow"
                        onClicked: {
                            TaskbarApps.launch(root.app);
                            root.popouts.hasCurrent = false;
                        }
                    }

                    SmallAction {
                        visible: !!root.app?.key
                        icon: "keep"
                        filled: TaskbarApps.isPinned(root.app?.key ?? "")
                        onClicked: TaskbarApps.isPinned(root.app.key) ? TaskbarApps.unpin(root.app.key) : TaskbarApps.pin(root.app.key)
                    }

                    SmallAction {
                        visible: root.cardCount > 1
                        icon: "close"
                        onClicked: {
                            root.closedFromHere = true;
                            for (const t of (root.app?.toplevels ?? []).slice())
                                TaskbarApps.close(t);
                        }
                    }
                }
            }
        }

        Row {
            id: cardsRow

            // (centred when the name and buttons over it need a little more room)
            Layout.alignment: Qt.AlignHCenter
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
        readonly property real previewW: Math.round(Math.max(110, Math.min(190, 108 * aspect)))
        readonly property real previewH: Math.round(Math.min(108, previewW / aspect))

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

                ThemedIcon {
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
                            font: Tokens.font.label.small
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
            implicitWidth: 22
            implicitHeight: 22
            radius: 11
            color: hovered ? Colours.palette.m3error : Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.9)
            opacity: card.pointerOn ? 1 : 0
            scale: card.pointerOn ? 1 : 0.7

            StateLayer {
                id: closeLayer

                radius: 11
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

    component SmallAction: StyledRect {
        id: sa

        property string icon
        property bool filled

        signal clicked

        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: "transparent"

        StateLayer {
            radius: 14
            onClicked: sa.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: sa.icon
            color: sa.filled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
            fill: sa.filled ? 1 : 0
        }
    }
}
