pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias icon: icon.text
    property alias label: label.text
    property alias status: status.text
    property bool keepPopupAsChild

    property alias open: floating.expanded
    property alias popupWidth: floating.contentWidth
    property alias popupHeight: floating.contentHeight
    property alias maxPopupHeight: floating.maxHeight
    property alias popupContent: floating.content
    readonly property alias popup: floating

    Layout.fillWidth: true
    implicitHeight: navLayout.implicitHeight + navLayout.anchors.margins * 2

    StateLayer {
        id: stateLayer

        onClicked: floating.expanded = !floating.expanded
    }

    RowLayout {
        id: navLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            color: Colours.palette.m3onSurfaceVariant
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
                id: status

                Layout.fillWidth: true
                visible: text
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
                animate: true
            }
        }

        Item {
            id: triggerArea

            implicitWidth: unfoldIcon.implicitWidth + Tokens.padding.extraSmall * 2
            implicitHeight: unfoldIcon.implicitHeight + Tokens.padding.extraSmall * 2

            MaterialIcon {
                id: unfoldIcon

                anchors.centerIn: parent
                text: "unfold_more"
                color: floating.expanded ? Colours.palette.m3primary : (stateLayer.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                fontStyle: Tokens.font.icon.medium

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }

    // Anchor spans the row's full height and right edge so the popup opens
    // cleanly below/above the row and flush with the chevron without overlapping it
    Item {
        id: triggerAnchor

        anchors.right: navLayout.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: triggerArea.width
    }

    FloatingPopup {
        id: floating

        attachTo: triggerAnchor
        ownArea: root
        keepAsChild: root.keepPopupAsChild
    }
}
