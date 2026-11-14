import QtQuick
import M3Shapes

Item {
    id: cc

    property int chipShape: MaterialShape.Cookie6Sided
    property string icon: ""
    property string title: ""
    property string subText: ""
    property string valueText: ""
    property color iconBg: NebulaTheme.colors.primaryContainer
    property color iconFg: NebulaTheme.colors.textOnPrimaryContainer
    property color titleColor: NebulaTheme.colors.textOnSurfaceVariant
    property color subColor: NebulaTheme.colors.textOnSurfaceVariant
    property color valueColor: NebulaTheme.colors.textOnSurface

    Item {
        id: chip

        x: 12
        y: 12
        width: 32
        height: 32

        MaterialShape {
            anchors.fill: parent
            shape: cc.chipShape
            color: cc.iconBg
        }

        Text {
            anchors.centerIn: parent
            text: cc.icon
            font.family: NebulaTheme.font.icons
            font.pixelSize: 17
            color: cc.iconFg
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: chip.verticalCenter
        text: cc.title
        font.family: NebulaTheme.font.family
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: cc.titleColor
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 13
        text: cc.subText
        visible: text !== ""
        font.family: NebulaTheme.font.family
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: cc.subColor
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        text: cc.valueText
        font.family: NebulaTheme.font.family
        font.pixelSize: 26
        font.weight: Font.DemiBold
        color: cc.valueColor
    }
}
