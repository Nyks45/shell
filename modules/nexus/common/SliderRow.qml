pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias icon: icon.text
    property alias label: label.text
    property alias valueLabel: valueLabel.text
    property real value
    property bool iconClickable

    signal moved(value: real)
    signal iconClicked

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins + rowLayout.anchors.topMargin

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.largeIncreased
        anchors.topMargin: Tokens.padding.large
        spacing: Tokens.spacing.medium

        Item {
            implicitWidth: icon.implicitWidth + (root.iconClickable ? Tokens.padding.extraSmall * 2 : 0)
            implicitHeight: icon.implicitHeight + (root.iconClickable ? Tokens.padding.extraSmall * 2 : 0)

            StateLayer {
                visible: root.iconClickable
                disabled: !root.iconClickable
                radius: Tokens.rounding.full
                onClicked: root.iconClicked()
            }

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                color: Colours.palette.m3onSurfaceVariant
                opacity: root.enabled || root.iconClickable ? 1 : 0.38
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    id: label

                    Layout.fillWidth: true
                    opacity: root.enabled ? 1 : 0.38
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    id: valueLabel

                    opacity: root.enabled ? 1 : 0.38
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Tokens.padding.medium * 2

                StyledSlider {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: parent.implicitHeight

                    radius: Tokens.rounding.small
                    value: root.value
                    enabled: root.enabled
                    onInteraction: v => root.moved(v)
                }
            }
        }
    }
}
