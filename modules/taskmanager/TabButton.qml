import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A page tab or small action: icon and optional label, filled while selected
StyledRect {
    id: root

    property string label
    property string icon
    property bool selected
    property bool danger
    property bool usable: true

    signal clicked

    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: Math.max(36, row.implicitHeight + Tokens.padding.small * 2)
    radius: Tokens.rounding.full
    color: selected ? Colours.palette.m3secondaryContainer : "transparent"
    opacity: usable ? 1 : 0.4

    StateLayer {
        anchors.fill: parent
        radius: parent.radius
        disabled: !root.usable
        onClicked: root.clicked()
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            fill: root.selected ? 1 : 0
            color: root.danger ? Colours.palette.m3error : root.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            font: Tokens.font.label.large
            color: root.danger ? Colours.palette.m3error : root.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        }
    }
}
