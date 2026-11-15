import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Services.UPower
import M3Shapes
import qs.nebula.components
import qs.nebula.services
import qs.nebula.theme

Item {
    id: root

    // The computer's battery; on a desktop PC (no battery) a wireless device's (mouse, keyboard,
    // headset...), read from the kernel: UPower reports a sleeping one as 0% and not present,
    // and Nebula's widget only said "No battery" there
    property var device: null // { name, level 0..1, status }
    readonly property bool peripheral: !Battery.available && device !== null
    readonly property bool asleep: peripheral && device.status === "Unknown"
    readonly property bool bAvailable: Battery.available || peripheral
    readonly property real bLevel: Battery.available ? Battery.level : peripheral ? device.level : 0
    readonly property int bPercent: Math.round(bLevel * 100)
    readonly property bool bCharging: Battery.available ? Battery.charging : peripheral && device.status === "Charging"
    readonly property bool bFull: Battery.available ? Battery.full : peripheral && device.status === "Full"
    readonly property bool bPluggedIn: Battery.available ? Battery.pluggedIn : bCharging || bFull
    readonly property real bTimeToEmpty: Battery.available ? Battery.timeToEmpty : 0
    readonly property real bTimeToFull: Battery.available ? Battery.timeToFull : 0
    readonly property string deviceName: {
        const m = device?.name ?? "";
        return m === "" ? "Device" : m.length > 18 ? m.slice(0, 17) + "…" : m;
    }

    Process {
        id: devices

        running: !Battery.available
        command: ["sh", "-c", "for d in /sys/class/power_supply/*; do [ \"$(cat \"$d/scope\" 2>/dev/null)\" = Device ] && [ -r \"$d/capacity\" ] && printf '%s|%s|%s\\n' \"$(cat \"$d/model_name\" 2>/dev/null)\" \"$(cat \"$d/capacity\")\" \"$(cat \"$d/status\" 2>/dev/null)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const first = text.split("\n").find(l => l.includes("|"));
                if (!first) {
                    root.device = null;
                    return;
                }
                const [name, cap, status] = first.split("|");
                root.device = { name: name, level: Math.max(0, Math.min(100, parseInt(cap) || 0)) / 100, status: status };
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: !Battery.available
        onTriggered: devices.running = true
    }

    property string shapeName: "Cookie12Sided"
    property real baseSize: 200
    property string colorRole: "secondary"
    readonly property var colors: Widgets.palette(colorRole)
    readonly property real gap: 14

    property real size: baseSize

    Behavior on size {
        enabled: !Widgets.resizing
        NumberAnimation {
            duration: Theme.anim.island
            easing.type: Easing.OutBack
            easing.overshoot: Theme.anim.overshoot
        }
    }

    readonly property real level: root.bAvailable ? root.bLevel : 0
    property real shownLevel: level

    Behavior on shownLevel {
        NumberAnimation {
            duration: Theme.anim.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.emphasizedDecel
        }
    }

    readonly property bool critical: root.bAvailable && level <= Settings.power.lowBattery / 100
    readonly property bool halfway: root.bAvailable && level <= 0.5
    property color accent: !root.bAvailable ? Colors.outline : critical ? Colors.errorColor : halfway ? Colors.tertiary : Colors.primary

    Behavior on accent {
        ColorAnimation { duration: Theme.anim.medium }
    }

    property real innerTarget: 0.4
    property real innerRatio: innerTarget
    property bool ready: false

    Behavior on innerRatio {
        enabled: root.ready
        NumberAnimation {
            duration: Theme.anim.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.emphasizedDecel
        }
    }

    function remeasure() {
        if (ref.width <= 0) return;
        let least = ref.width / 2;
        for (let a = 0; a < 360; a += 4) least = Math.min(least, ref.distanceAtAngle(a));
        innerTarget = Math.max(0.2, least / ref.width);
        ready = true;
    }

    readonly property real ringWidth: size * 0.07
    readonly property real ringRadius: Math.min(size * 0.37, innerRatio * size - ringWidth / 2 - size * 0.04)
    readonly property real sweep: Math.min(360, 360 * shownLevel)
    readonly property real trackSweep: Math.max(0, 360 - sweep - gap * 2)

    readonly property real numberSize: ringRadius * (root.bPercent >= 100 ? 0.62 : 0.8)
    readonly property real percentSize: ringRadius * 0.27
    readonly property real percentGap: ringRadius * 0.03
    readonly property real lineGap: ringRadius * 0.03
    readonly property real pillPadding: ringRadius * 0.1
    readonly property real pillPaddingY: ringRadius * 0.05
    readonly property real iconSize: ringRadius * 0.22
    readonly property real iconGap: ringRadius * 0.05

    readonly property real innerRadius: ringRadius - ringWidth / 2 - size * 0.03
    readonly property real pillWidth: statusMetrics.advanceWidth + pillPadding * 2 + (root.bCharging ? iconSize + iconGap : 0)
    readonly property real blockHeight: (root.bAvailable ? numberMetrics.height + lineGap : 0) + statusMetrics.height + pillPaddingY * 2
    readonly property real numberReach: numberMetrics.advanceWidth / 2 + percentGap + percentMetrics.advanceWidth
    readonly property real reach: Math.max(Math.hypot(pillWidth / 2, blockHeight / 2), root.bAvailable ? Math.hypot(numberReach, blockHeight / 2) : 0)
    readonly property real fit: reach > 0 ? Math.min(1, innerRadius / reach) : 1

    function duration(seconds) {
        const minutes = Math.round(seconds / 60);
        if (minutes < 1) return "";
        return minutes >= 60 ? Math.floor(minutes / 60) + "h " + (minutes % 60) + "m" : minutes + "m";
    }

    readonly property string status: {
        if (!root.bAvailable) return "No battery";
        if (root.peripheral) return root.bCharging ? root.deviceName + " · charging" : root.asleep ? root.deviceName + " · asleep" : root.deviceName;
        if (root.bFull) return "Full";
        const time = duration(root.bCharging ? root.bTimeToFull : root.bTimeToEmpty);
        if (root.bCharging) return time !== "" ? time + " to full" : "Charging";
        if (root.bPluggedIn) return "Plugged in";
        return time !== "" ? time + " left" : "On battery";
    }

    implicitWidth: size
    implicitHeight: size

    GlassShape {
        id: body
        anchors.fill: parent
        shape: MaterialShape[root.shapeName] ?? MaterialShape.Cookie12Sided
        fill: root.colors.fill
        animationDuration: Theme.anim.slow
        animationEasing.type: Easing.OutBack
        animationEasing.overshoot: Theme.anim.overshoot
    }

    MaterialShape {
        id: ref
        width: 200
        height: 200
        visible: false
        shape: body.shape
        animationDuration: 0

        onShapeChanged: Qt.callLater(root.remeasure)
        Component.onCompleted: Qt.callLater(root.remeasure)
    }

    Shape {
        anchors.fill: parent
        visible: root.bAvailable
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.ringWidth
            strokeColor: root.accent
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: Math.max(0.5, root.sweep)
            }
        }

        ShapePath {
            strokeWidth: root.trackSweep > 0 ? root.ringWidth : 0
            strokeColor: Qt.alpha(root.colors.text, 0.2)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90 + root.sweep + root.gap
                sweepAngle: root.trackSweep
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: root.lineGap * root.fit

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.bAvailable
            implicitWidth: number.implicitWidth
            implicitHeight: number.implicitHeight

            Text {
                id: number
                text: root.bPercent
                font.family: Theme.font.family
                font.pixelSize: root.numberSize * root.fit
                font.weight: Font.DemiBold
                color: root.colors.text
            }

            Text {
                anchors.left: number.right
                anchors.leftMargin: root.percentGap * root.fit
                anchors.top: parent.top
                anchors.topMargin: root.ringRadius * 0.12 * root.fit
                text: "%"
                font.family: Theme.font.family
                font.pixelSize: root.percentSize * root.fit
                font.weight: Font.Medium
                color: root.colors.text
                opacity: 0.8
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: statusRow.implicitWidth + root.pillPadding * 2 * root.fit
            implicitHeight: statusRow.implicitHeight + root.pillPaddingY * 2 * root.fit
            radius: height / 2
            color: Qt.alpha(root.colors.text, 0.16)

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: root.iconGap * root.fit

                Text {
                    visible: root.bCharging
                    text: "bolt"
                    font.family: Theme.font.icons
                    font.pixelSize: root.iconSize * root.fit
                    color: root.accent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.status
                    font.family: Theme.font.family
                    font.pixelSize: statusMetrics.font.pixelSize * root.fit
                    font.weight: Font.Medium
                    color: root.colors.text
                }
            }
        }
    }

    TextMetrics {
        id: numberMetrics
        text: root.bPercent
        font.family: Theme.font.family
        font.pixelSize: root.numberSize
        font.weight: Font.DemiBold
    }

    TextMetrics {
        id: percentMetrics
        text: "%"
        font.family: Theme.font.family
        font.pixelSize: root.percentSize
        font.weight: Font.Medium
    }

    TextMetrics {
        id: statusMetrics
        text: root.status
        font.family: Theme.font.family
        font.pixelSize: root.ringRadius * (root.bAvailable ? 0.19 : 0.3)
        font.weight: Font.Medium
    }
}
