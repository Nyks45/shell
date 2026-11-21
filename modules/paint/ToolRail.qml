pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import "Tools.js" as Tools

// The tools, down the left side (scrolls when the window is short)
Item {
    id: root

    required property var win

    implicitWidth: rail.width + Tokens.padding.small

    StyledRect {
        id: rail

        anchors.verticalCenter: parent.verticalCenter
        width: col.implicitWidth + Tokens.padding.small * 2
        height: Math.min(parent.height - Tokens.padding.small * 2, col.implicitHeight + Tokens.padding.small * 2)
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainer

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: col

                spacing: 2

                Repeater {
                    model: Tools.list

                    Column {
                        id: entry

                        required property var modelData
                        required property int index

                        spacing: 2

                        Rectangle {
                            visible: entry.index > 0 && Tools.list[entry.index - 1].group !== entry.modelData.group
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 22
                            height: 1
                            color: Colours.palette.m3outlineVariant
                        }

                        Item {
                            visible: entry.index > 0 && Tools.list[entry.index - 1].group !== entry.modelData.group
                            width: 1
                            height: 2
                        }

                        PaintButton {
                            objectName: `tool:${entry.modelData.id}`
                            type: IconButton.Tonal
                            isToggle: true
                            checked: root.win.tool === entry.modelData.id
                            icon: entry.modelData.icon
                            tip: Tr.tr(Tools.names[entry.modelData.id])
                            keys: entry.modelData.key
                            tipSide: PaintTip.Right
                            inactiveColour: "transparent"
                            onClicked: root.win.setTool(entry.modelData.id)
                        }
                    }
                }
            }
        }

        // more tools below or above
        Rectangle {
            visible: flick.interactive && !flick.atYEnd
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 3
            width: 16
            height: 3
            radius: 1.5
            color: Colours.palette.m3outline
        }
    }
}
