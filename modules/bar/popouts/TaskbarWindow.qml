pragma ComponentBehavior: Bound

import QtQuick
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
                source: root.app?.entry?.icon ? Quickshell.iconPath(root.app.entry.icon, "image-missing") : Icons.getAppIcon(root.app?.cls ?? "", "image-missing")
            }

            StyledText {
                text: root.appName
                font: Tokens.font.body.small
            }
        }

        // A pinned app with no window here: open it.
        TextButton {
            visible: (root.app?.toplevels.length ?? 0) === 0
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
        // The preview takes the window's shape, within 150 x 96 (no empty frame).
        readonly property real aspect: {
            const size = modelData.lastIpcObject.size ?? [16, 10];
            return Math.max(0.2, size[0] / Math.max(1, size[1]));
        }
        readonly property real previewW: Math.round(Math.min(150, 96 * aspect))
        readonly property real previewH: Math.round(Math.min(96, 150 / aspect))

        implicitWidth: Math.max(previewW, 72) + Tokens.padding.small * 2
        implicitHeight: frame.implicitHeight + title.implicitHeight + Tokens.spacing.small + Tokens.padding.small * 2

        scale: hover.containsMouse || closeBtn.hovered ? 1.03 : 1
        opacity: 0
        Component.onCompleted: opacity = 1

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
            color: Colours.tPalette.m3surfaceContainerHighest

            Item {
                // Live while shown; a minimized (hidden) window has nothing to
                // capture: its icon instead.
                ScreencopyView {
                    anchors.centerIn: parent
                    visible: !card.minimized
                    captureSource: card.minimized ? null : card.modelData.wayland
                    live: visible
                    constraintSize.width: frame.implicitWidth
                    constraintSize.height: frame.implicitHeight
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: card.minimized
                    spacing: 0

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.getAppCategoryIcon(card.modelData.lastIpcObject.class, "terminal")
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Minimized")
                        color: Colours.palette.m3onSurfaceVariant
                    }
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

            anchors.top: frame.top
            anchors.right: frame.right
            anchors.margins: Tokens.padding.extraSmall
            implicitWidth: closeIcon.implicitHeight + Tokens.padding.extraSmall * 2
            implicitHeight: implicitWidth
            radius: Tokens.rounding.full
            color: hovered ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHighest
            opacity: hover.containsMouse || hovered ? 1 : 0
            scale: hover.containsMouse || hovered ? 1 : 0.7

            StateLayer {
                id: closeLayer

                radius: Tokens.rounding.full
                color: Colours.palette.m3onErrorContainer
                onClicked: TaskbarApps.close(card.modelData)
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
