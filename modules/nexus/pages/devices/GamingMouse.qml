pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// A Logitech mouse's own settings (through Solaar's command line): its battery,
// and either its onboard profile (what G HUB set on Windows) or DPI and report
// rate set here (the mouse then follows the computer; caelestia-devices.service
// sets them again when it reconnects). Shown only when such a mouse is there.
ColumnLayout {
    id: root

    property var info: null
    readonly property var mouse: info?.mice?.[0] ?? null
    readonly property string helper: `${Paths.libdir}/caelestia-devices`
    readonly property string what: Tr.tr("Change the mouse")
    readonly property bool busy: Admin.jobs.some(j => j.what === root.what)
    readonly property var dpis: [400, 800, 1200, 1600, 2400, 3200]
    readonly property var rateNames: ({
            "8ms": "125 Hz",
            "4ms": "250 Hz",
            "2ms": "500 Hz",
            "1ms": "1000 Hz",
            "500us": "2000 Hz",
            "250us": "4000 Hz",
            "125us": "8000 Hz"
        })

    function load(): void {
        if (!proc.running)
            proc.running = true;
    }

    function set(key: string, value: string): void {
        Admin.exec([helper, "mouse-set", key, value], what, () => root.load());
        // Kept after a reconnect or a restart
        if (key !== "profile" || value === "off")
            Admin.exec(["systemctl", "--user", "enable", "--now", "caelestia-devices.service"], Tr.tr("Keep the mouse's settings"));
    }

    Layout.fillWidth: true
    visible: !!mouse
    spacing: Tokens.spacing.extraSmall / 2

    Component.onCompleted: load()

    SectionHeader {
        text: root.mouse?.name ?? ""
    }

    InfoRow {
        visible: root.mouse?.battery !== undefined && root.mouse?.battery !== null
        icon: root.mouse?.charging ? "battery_charging_full" : (root.mouse?.battery ?? 100) < 20 ? "battery_alert" : "battery_full"
        label: Tr.tr("Battery")
        value: `${root.mouse?.battery ?? 0}%`
        subtext: root.mouse?.charging ? Tr.tr("Charging") : ""
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.small
        Layout.topMargin: Tokens.spacing.small
        visible: !!root.mouse && !root.mouse.awake
        text: Tr.tr("Asleep: move it to see and change its settings.")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
    }

    ConnectedRect {
        Layout.fillWidth: true
        visible: !!root.mouse?.awake
        implicitHeight: modeL.implicitHeight + Tokens.padding.medium * 2

        ColumnLayout {
            id: modeL

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.mouse?.host ? Tr.tr("Set here: the DPI and report rate below") : Tr.tr("Its own profile: what G HUB saved on it (DPI, report rate, buttons)")
                wrapMode: Text.WordWrap
                font: Tokens.font.body.small
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                TextButton {
                    enabled: !root.busy
                    text: Tr.tr("Its own profile")
                    isToggle: true
                    followChecked: true
                    checked: !root.mouse?.host
                    type: TextButton.Tonal
                    onClicked: root.set("profile", "on")
                }

                TextButton {
                    enabled: !root.busy
                    text: Tr.tr("Set here")
                    isToggle: true
                    followChecked: true
                    checked: !!root.mouse?.host
                    type: TextButton.Tonal
                    onClicked: root.set("profile", "off")
                }
            }
        }
    }

    ConnectedRect {
        Layout.fillWidth: true
        visible: !!root.mouse?.host
        implicitHeight: dpiL.implicitHeight + Tokens.padding.medium * 2

        ColumnLayout {
            id: dpiL

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            StyledText {
                text: Tr.tr("Sensitivity (DPI): %1").arg(root.mouse?.dpi ?? "")
                font: Tokens.font.body.small
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.dpis

                    TextButton {
                        required property int modelData

                        enabled: !root.busy
                        text: String(modelData)
                        isToggle: true
                        followChecked: true
                        checked: root.mouse?.dpi === modelData
                        type: TextButton.Tonal
                        onClicked: root.set("dpi", String(modelData))
                    }
                }
            }
        }
    }

    StepperRow {
        visible: !!root.mouse?.host
        label: Tr.tr("Exact DPI")
        from: 100
        to: 32000
        stepSize: 50
        value: dpiTimer.wanted > 0 ? dpiTimer.wanted : (root.mouse?.dpi ?? 1600)
        onMoved: v => {
            dpiTimer.wanted = v;
            dpiTimer.restart();
        }
    }

    // The stepper's value, sent once it stops changing
    Timer {
        id: dpiTimer

        property real wanted: -1

        interval: 600
        onTriggered: {
            root.set("dpi", String(Math.round(wanted)));
            wanted = -1;
        }
    }

    ConnectedRect {
        Layout.fillWidth: true
        visible: !!root.mouse?.host
        implicitHeight: rateL.implicitHeight + Tokens.padding.medium * 2

        ColumnLayout {
            id: rateL

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.small

            StyledText {
                text: Tr.tr("Report rate (higher: smoother, more battery)")
                font: Tokens.font.body.small
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: (root.mouse?.rates ?? []).slice().reverse()

                    TextButton {
                        required property string modelData

                        enabled: !root.busy
                        text: root.rateNames[modelData] ?? modelData
                        isToggle: true
                        followChecked: true
                        checked: root.mouse?.rate === modelData
                        type: TextButton.Tonal
                        onClicked: root.set("rate", modelData)
                    }
                }
            }
        }
    }

    Process {
        id: proc

        command: [root.helper, "mouse"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
}
