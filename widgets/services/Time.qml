pragma Singleton

import QtQuick
import Quickshell
import Caelestia.I18n

Singleton {
    id: root

    // The shell's own clock setting (Settings › Time & language)
    readonly property bool use24h: !Units.twelveHourClock

    readonly property date now: clock.date
    readonly property string time: Qt.formatDateTime(clock.date, use24h ? "HH:mm" : "h:mm AP")
    readonly property string date: clock.date.toLocaleString(Qt.locale("en_US"), "ddd, MMM d")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
