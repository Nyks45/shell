import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Hover popout of a taskbar entry: the window's icon, title and app.
Item {
    id: root

    required property PopoutState popouts
    readonly property HyprlandToplevel toplevel: popouts.taskbarToplevel ?? null
    readonly property bool minimized: toplevel?.lastIpcObject.tags?.includes("minimized") ?? false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        IconImage {
            Layout.alignment: Qt.AlignVCenter
            implicitSize: details.implicitHeight
            asynchronous: true
            source: Icons.getAppIcon(root.toplevel?.lastIpcObject.class ?? "", "image-missing")
        }

        ColumnLayout {
            id: details

            spacing: 0

            StyledText {
                Layout.maximumWidth: 360
                text: root.toplevel?.title ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.maximumWidth: 360
                text: {
                    const app = root.toplevel?.lastIpcObject.class ?? "";
                    return root.minimized ? `${app} · ${Tr.trCtx("Minimized", "taskbar window state")}` : app;
                }
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
