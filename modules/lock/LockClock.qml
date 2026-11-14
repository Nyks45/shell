import QtQuick
import M3Shapes
import Caelestia.I18n
import qs.services

Item {
    id: root

    property real flash: 0

    function triggerErrorFlash(): void {
        flashAnim.restart();
    }

    SequentialAnimation {
        id: flashAnim

        NumberAnimation {
            target: root
            property: "flash"
            to: 1
            duration: 80
        }
        NumberAnimation {
            target: root
            property: "flash"
            to: 0
            duration: 600
            easing.type: Easing.OutCubic
        }
    }

    MaterialShape {
        anchors.fill: parent
        shape: MaterialShape.Cookie12Sided
        color: Qt.tint(Qt.alpha(NebulaTheme.colors.primaryContainer, NebulaTheme.lock.surfaceTint), Qt.alpha(NebulaTheme.colors.errorContainer, root.flash))

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 50000
            loops: Animation.Infinite
            running: root.visible
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Text {
                text: `${Time.hourStr}:${Time.minuteStr}`
                font.family: NebulaTheme.font.family
                font.pixelSize: root.width * 0.24
                font.weight: Font.Medium
                color: NebulaTheme.colors.textOnPrimaryContainer
            }

            Text {
                visible: Units.twelveHourClock && Time.amPmStr !== ""
                anchors.baseline: parent.children[0].baseline
                text: Time.amPmStr
                font.family: NebulaTheme.font.family
                font.pixelSize: root.width * 0.08
                font.weight: Font.Medium
                color: Qt.alpha(NebulaTheme.colors.textOnPrimaryContainer, 0.8)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("ddd, MMM d")
            font.family: NebulaTheme.font.family
            font.pixelSize: root.width * 0.065
            color: Qt.alpha(NebulaTheme.colors.textOnPrimaryContainer, 0.78)
        }
    }
}
