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

// The graphics card (nvidia-settings' job on Wayland): live readings, the
// power limit (kept across restarts by a small boot service), persistence
// mode, and what the driver is set up with. Fan control isn't possible on
// Wayland with NVIDIA (nvidia-smi can't, nvidia-settings needs X): shown only.
PageBase {
    id: root

    property var gpu: null
    // The power limit being chosen (applied with Apply)
    property real limit: -1
    readonly property string limitWhat: Tr.tr("Set the graphics card's power limit")

    function load(): void {
        if (!proc.running)
            proc.running = true;
    }

    title: Tr.tr("Graphics card")

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.gpu !== null && !root.gpu.nvidia
            text: Tr.tr("No NVIDIA graphics card found (nvidia-smi).")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        SectionHeader {
            first: true
            visible: !!root.gpu?.nvidia
            text: root.gpu?.name ?? ""
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "thermostat"
            label: Tr.tr("Temperature")
            value: `${Math.round(root.gpu?.temperatureGpu ?? 0)} °C`
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "bolt"
            label: Tr.tr("Power")
            value: `${Math.round(root.gpu?.powerDraw ?? 0)} W / ${Math.round(root.gpu?.powerLimit ?? 0)} W`
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "speed"
            label: Tr.tr("Load")
            value: `${Math.round(root.gpu?.utilizationGpu ?? 0)} %`
            subtext: Tr.tr("Graphics %1 MHz (up to %2) · memory %3 MHz").arg(Math.round(root.gpu?.clocksGr ?? 0)).arg(Math.round(root.gpu?.clocksMaxGr ?? 0)).arg(Math.round(root.gpu?.clocksMem ?? 0))
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "memory"
            label: Tr.tr("Video memory")
            value: `${((root.gpu?.memoryUsed ?? 0) / 1024).toFixed(1)} / ${((root.gpu?.memoryTotal ?? 0) / 1024).toFixed(0)} GB`
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "mode_fan"
            label: Tr.tr("Fan")
            value: `${Math.round(root.gpu?.fanSpeed ?? 0)} %`
            subtext: Tr.tr("Automatic (fan control isn't possible on Wayland with NVIDIA's driver)")
        }

        // Power limit
        SectionHeader {
            visible: !!root.gpu?.nvidia
            text: Tr.tr("Power")
        }

        StepperRow {
            visible: !!root.gpu?.nvidia
            label: Tr.tr("Power limit")
            subtext: Tr.tr("Watts: lower is cooler and quieter, a little slower (default %1 W)").arg(Math.round(root.gpu?.powerDefaultLimit ?? 0))
            from: root.gpu?.powerMinLimit ?? 0
            to: root.gpu?.powerMaxLimit ?? 999
            stepSize: 5
            value: root.limit >= 0 ? root.limit : (root.gpu?.powerLimit ?? 0)
            onMoved: v => root.limit = v
        }

        ToggleRow {
            visible: !!root.gpu?.nvidia
            text: Tr.tr("Persistence mode")
            subtext: Tr.tr("Keeps the driver ready between uses: games and apps start using the card a little faster (nvidia-persistenced)")
            checked: !!root.gpu?.persistenced
            onToggled: Admin.run("gpu-persistence", [checked ? "on" : "off"], checked ? Tr.tr("Turn on persistence mode") : Tr.tr("Turn off persistence mode"), () => root.load())
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.gpu?.nvidia && (root.limit >= 0 && root.limit !== root.gpu.powerLimit || (root.gpu.powerLimit !== root.gpu.powerDefaultLimit))
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Admin.jobs.some(j => j.what === root.limitWhat) ? Tr.tr("Setting it…") : root.limit >= 0 && root.limit !== root.gpu?.powerLimit ? Tr.tr("Kept after a restart too") : Tr.tr("Not the default limit")
                color: Colours.palette.m3primary
                font: Tokens.font.body.small
            }

            TextButton {
                visible: (root.gpu?.powerLimit ?? 0) !== (root.gpu?.powerDefaultLimit ?? 0)
                text: Tr.tr("Default")
                type: TextButton.Text
                onClicked: Admin.run("gpu-power", ["default"], root.limitWhat, () => {
                    root.limit = -1;
                    root.load();
                })
            }

            TextButton {
                visible: root.limit >= 0 && root.limit !== root.gpu?.powerLimit
                text: Tr.tr("Apply")
                type: TextButton.Filled
                onClicked: Admin.run("gpu-power", [String(Math.round(root.limit))], root.limitWhat, () => {
                    root.limit = -1;
                    root.load();
                })
            }
        }

        // How the driver is set up
        SectionHeader {
            visible: !!root.gpu?.nvidia
            text: Tr.tr("Driver")
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "developer_board"
            label: Tr.tr("Driver version")
            value: root.gpu?.driverVersion ?? ""
            subtext: root.gpu?.openModules ? Tr.tr("Open kernel modules") : Tr.tr("Proprietary kernel modules")
        }

        InfoRow {
            visible: !!root.gpu?.nvidia
            icon: "display_settings"
            label: Tr.tr("Display support")
            value: root.gpu?.modeset === "Y" ? Tr.tr("Ready for Wayland") : Tr.tr("Modesetting off")
            subtext: Tr.tr("Kernel modesetting %1 · framebuffer %2 · variable refresh is on for capable monitors (set per monitor in Display)").arg(root.gpu?.modeset === "Y" ? Tr.tr("on") : Tr.tr("off")).arg(root.gpu?.fbdev === "Y" ? Tr.tr("on") : Tr.tr("off"))
        }

        // Live readings while shown
        Timer {
            running: root.visible
            repeat: true
            interval: 2000
            onTriggered: root.load()
        }

        Process {
            id: proc

            command: [`${Paths.libdir}/caelestia-gaming`, "gpu"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.gpu = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}
