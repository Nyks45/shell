pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice

    readonly property bool available: device !== null && device.isLaptopBattery && device.isPresent
    readonly property real level: available ? device.percentage : 0
    readonly property int percent: Math.round(level * 100)

    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: available && !UPower.onBattery
    readonly property bool full: available && device.state === UPowerDeviceState.FullyCharged
    // "Low" as the shell's battery warnings define it: their highest level (20 % by default)
    readonly property real lowLevel: Math.max(0, ...[...GlobalConfig.general.battery.warnLevels.values].map(l => l.level ?? 0)) / 100
    readonly property bool low: available && !pluggedIn && level < lowLevel

    readonly property real timeToEmpty: available ? device.timeToEmpty : 0
    readonly property real timeToFull: available ? device.timeToFull : 0
}
