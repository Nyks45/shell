import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A row with a tick box (choosing items, e.g. which updates to install):
// label, a smaller line under it, a value on the right
ConnectedRect {
    id: root

    property alias label: label.text
    property alias subtext: sub.text
    property alias value: value.text
    property bool checked
    property bool disabled

    signal toggled(checked: bool)

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2
    opacity: disabled ? 0.5 : 1

    StateLayer {
        disabled: root.disabled
        onClicked: root.toggled(!root.checked)
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: root.checked ? "check_box" : "check_box_outline_blank"
            fill: root.checked ? 1 : 0
            color: root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                id: sub

                Layout.fillWidth: true
                visible: text
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            id: value

            visible: text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
