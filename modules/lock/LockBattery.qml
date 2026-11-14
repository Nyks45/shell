import QtQuick
import Quickshell.Services.UPower
import Caelestia.Services

Item {
    id: root

    readonly property bool hasBattery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
    readonly property real ringLevel: hasBattery ? UPower.displayDevice.percentage : Cpu.percentage
    readonly property bool low: hasBattery ? ringLevel <= NebulaTheme.batteryRing.lowLevel && UPower.onBattery : Cpu.temperature > 85
    readonly property bool charging: hasBattery && !UPower.onBattery

    ServiceRef {
        service: Cpu
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(NebulaTheme.colors.secondaryContainer, NebulaTheme.lock.surfaceTint)
    }

    BatteryRing {
        anchors.fill: parent
        anchors.margins: 6
        level: root.ringLevel
        low: root.low
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.hasBattery ? root.charging : true
            text: root.hasBattery ? "bolt" : "memory"
            font.family: NebulaTheme.font.icons
            font.pixelSize: root.width * 0.2
            color: NebulaTheme.colors.textOnSecondaryContainer
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hasBattery ? `${Math.round(UPower.displayDevice.percentage * 100)}%` : `${Math.round(Cpu.percentage * 100)}%`
            font.family: NebulaTheme.font.family
            font.pixelSize: root.width * 0.22
            font.weight: Font.Medium
            color: NebulaTheme.colors.textOnSecondaryContainer
        }
    }
}
