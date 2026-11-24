import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Settings that need something not there (a Hyprland plugin, a program): what
// is missing, what it means, and a way to get it (a button, optional).
ConnectedRect {
    id: root

    property alias text: title.text
    property alias subtext: sub.text
    property string icon: "extension_off"
    property string actionText
    property bool neutral

    readonly property Item prevItem: standalone ? Rows.adjacentVisual(root, -1) : null
    readonly property Item nextItem: standalone ? Rows.adjacentVisual(root, 1) : null

    signal action

    standalone: !neutral
    Layout.fillWidth: true
    Layout.topMargin: standalone && prevItem && prevItem.isSectionHeader !== true ? Math.max(0, Tokens.spacing.largeIncreased - root.gap) : 0
    Layout.bottomMargin: standalone && nextItem && nextItem.isGroupRow === true && nextItem.groupStart !== true ? Math.max(0, Tokens.spacing.largeIncreased - root.gap) : 0
    implicitHeight: Math.ceil(layout.implicitHeight) + Tokens.padding.medium * 2
    fillColour: root.neutral ? Colours.tPalette.m3surfaceContainer : Colours.palette.m3tertiaryContainer

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: root.icon
            color: root.neutral ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onTertiaryContainer
            fontStyle: Tokens.font.icon.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: title

                Layout.fillWidth: true
                color: root.neutral ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                id: sub

                Layout.fillWidth: true
                visible: text
                color: root.neutral ? Colours.palette.m3outline : Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.8)
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }
        }

        TextButton {
            visible: root.actionText
            text: root.actionText
            type: TextButton.Tonal
            onClicked: root.action()
        }
    }
}
