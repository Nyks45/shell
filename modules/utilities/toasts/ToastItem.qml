import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.effects
import qs.services

// The shell's own messages ("Copied", "Do not disturb enabled"...), as cards like the
// notifications': the same glass card, rim and type; the kind (success, warning, error) only
// colours the round icon.
StyledRect {
    id: root

    required property Toast modelData

    readonly property color accent: {
        if (root.modelData.type === Toast.Success)
            return Colours.palette.m3success;
        if (root.modelData.type === Toast.Warning)
            return Colours.palette.m3tertiary;
        if (root.modelData.type === Toast.Error)
            return Colours.palette.m3error;
        return Colours.palette.m3secondaryContainer;
    }
    readonly property color onAccent: {
        if (root.modelData.type === Toast.Success)
            return Colours.palette.m3onSuccess;
        if (root.modelData.type === Toast.Warning)
            return Colours.palette.m3onTertiary;
        if (root.modelData.type === Toast.Error)
            return Colours.palette.m3onError;
        return Colours.palette.m3onSecondaryContainer;
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 2
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: 40
            implicitHeight: 40
            radius: Tokens.rounding.full
            color: root.accent

            MaterialIcon {
                anchors.centerIn: parent
                text: root.modelData.icon
                color: root.onAccent
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Tr.trMarked(root.modelData.title)
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                textFormat: Text.StyledText
                text: Tr.trMarked(root.modelData.message)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }
        }
    }
}
