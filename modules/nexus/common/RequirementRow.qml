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

    signal action

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2
    color: Colours.palette.m3tertiaryContainer

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
            color: Colours.palette.m3onTertiaryContainer
            fontStyle: Tokens.font.icon.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: title

                Layout.fillWidth: true
                color: Colours.palette.m3onTertiaryContainer
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                id: sub

                Layout.fillWidth: true
                visible: text
                color: Qt.alpha(Colours.palette.m3onTertiaryContainer, 0.8)
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
