import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property alias menuItems: splitButton.menuItems
    property alias active: splitButton.active
    property alias fallbackText: splitButton.fallbackText
    property alias fallbackIcon: splitButton.fallbackIcon
    property alias menuOnTop: splitButton.menuOnTop

    // Three or fewer short choices show as segmented buttons (like DankMaterialShell's
    // settings), a check on the chosen one; longer lists keep the drop-down
    property bool segmentedAllowed: true
    readonly property bool segmented: segmentedAllowed && menuItems.length > 0 && menuItems.length <= 3 && Array.from(menuItems).every(i => (i.text ?? "").length <= 16)

    signal selected(item: MenuItem)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2
    clip: false
    z: splitButton.expanded ? 1 : 0

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

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
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        Row {
            visible: root.segmented
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.segmented ? Array.from(root.menuItems) : []

                StyledRect {
                    id: seg

                    required property var modelData
                    readonly property bool chosen: root.active === modelData

                    implicitWidth: segRow.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: segRow.implicitHeight + Tokens.padding.small * 2
                    radius: height / 2
                    color: chosen ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                    StateLayer {
                        color: seg.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: {
                            if (!seg.chosen)
                                root.selected(seg.modelData);
                        }
                    }

                    Row {
                        id: segRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: seg.chosen
                            text: "check"
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: seg.modelData.text ?? ""
                            color: seg.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }
                    }
                }
            }
        }

        SplitButton {
            id: splitButton

            visible: !root.segmented
            type: SplitButton.Tonal
            stateLayer.onClicked: splitButton.expanded = !splitButton.expanded
            menu.onItemSelected: item => root.selected(item)
        }
    }
}
