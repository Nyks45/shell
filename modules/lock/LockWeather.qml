import QtQuick
import M3Shapes
import qs.services

Item {
    id: root

    readonly property var cc: Weather.cc
    readonly property int shapeType: {
        const code = Number(cc?.weatherCode ?? -1);
        const day = cc ? cc.isDay !== 0 : true;
        if (code === 0 || code === 1)
            return day ? MaterialShape.Sunny : MaterialShape.Circle;
        if (code === 2 || code === 3)
            return MaterialShape.Puffy;
        if (code === 45 || code === 48)
            return MaterialShape.Oval;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return MaterialShape.Cookie9Sided;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return MaterialShape.Cookie12Sided;
        if (code >= 95)
            return MaterialShape.SoftBurst;
        return MaterialShape.Cookie9Sided;
    }

    MaterialShape {
        anchors.fill: parent
        shape: root.shapeType
        color: Qt.alpha(NebulaTheme.colors.tertiaryContainer, NebulaTheme.lock.surfaceTint)
        animationDuration: NebulaTheme.anim.slow

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 70000
            loops: Animation.Infinite
            running: root.visible
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.icon
            font.family: NebulaTheme.font.icons
            font.pixelSize: root.width * 0.22
            color: NebulaTheme.colors.textOnTertiaryContainer
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.temp
            font.family: NebulaTheme.font.family
            font.pixelSize: root.width * 0.24
            font.weight: Font.Medium
            color: NebulaTheme.colors.textOnTertiaryContainer
        }
    }
}
