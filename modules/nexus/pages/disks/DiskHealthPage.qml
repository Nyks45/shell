pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

// A drive's health (SMART / NVMe): plain status first, the numbers that
// matter (temperature, wear, data written, errors), self-tests, and every
// attribute for those who want them.
PageBase {
    id: root

    readonly property var drive: Disks.drive(nState.selectedDrive)
    readonly property var h: drive?.health ?? null
    // caelestia-disks attributes: NVMe numbers or the ATA attribute table
    property var details: null

    function load(): void {
        if (drive) {
            attrProc.command = [Disks.helper, "attributes", drive.id];
            attrProc.running = true;
        }
    }

    function number(n: real): string {
        return n === undefined || n === null ? "" : Number(n).toLocaleString(Qt.locale(), "f", 0);
    }

    title: drive ? Tr.tr("Health of %1").arg(drive.model || drive.device) : Tr.tr("Health")
    isSubPage: true

    Component.onCompleted: {
        Disks.open();
        load();
    }
    Component.onDestruction: Disks.close()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Non-visual (the page takes one item: it lives in the column)
        Process {
            id: attrProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.details = JSON.parse(text);
                    } catch (e) {
                        root.details = null;
                    }
                }
            }
        }

        RowButton {
            visible: !root.h
            icon: "info"
            text: Tr.tr("This drive doesn't report its health")
            disabled: true
        }

        // ---- Status ----------------------------------------------------------
        ConnectedRect {
            visible: !!root.h
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: statusRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: root.h?.status === "good" ? "health_and_safety" : "warning"
                    color: root.h?.status === "failing" ? Colours.palette.m3error : root.h?.status === "warning" ? Colours.palette.m3tertiary : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.h?.status === "failing" ? Tr.tr("Failing") : root.h?.status === "warning" ? Tr.tr("Showing problems") : Tr.tr("Healthy")
                        font: Tokens.font.title.builders.medium.build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.h?.status === "failing" ? Tr.tr("It reports that it is failing. Copy its data elsewhere now and replace it.") : root.h?.status === "warning" ? Tr.tr("It has had errors (bad sectors or past failures). Keep backups and watch it.") : Tr.tr("It reports no problems.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ---- The numbers that matter ---------------------------------------
        SectionHeader {
            visible: !!root.h
            text: Tr.tr("Details")
        }

        InfoRow {
            visible: root.h?.temperature !== null && root.h?.temperature !== undefined
            icon: "device_thermostat"
            label: Tr.tr("Temperature")
            subtext: root.details?.warningTemperature ? Tr.tr("Too hot from %1 °C").arg(root.details.warningTemperature) : ""
            value: `${root.h?.temperature ?? ""} °C`
        }

        InfoRow {
            visible: !!root.h
            icon: "schedule"
            label: Tr.tr("Powered on")
            value: Tr.tr("%1 hours").arg(root.number(root.h?.powerOnHours))
        }

        InfoRow {
            visible: root.details?.kind === "nvme" && root.details.wear !== undefined
            icon: "battery_horiz_050"
            label: Tr.tr("Wear")
            subtext: Tr.tr("How much of its rated life is used (100% is the maker's estimate, not the end)")
            value: `${root.details?.wear ?? ""}%`
        }

        InfoRow {
            visible: root.details?.kind === "nvme" && root.details.spare !== undefined
            icon: "inventory"
            label: Tr.tr("Spare capacity")
            subtext: Tr.tr("Reserve for worn-out cells; low below %1%").arg(root.details?.spareThreshold ?? "")
            value: `${root.details?.spare ?? ""}%`
        }

        InfoRow {
            visible: root.details?.kind === "nvme" && root.details.dataWritten !== undefined
            icon: "upload"
            label: Tr.tr("Data written")
            value: Disks.human(root.details?.dataWritten ?? 0)
        }

        InfoRow {
            visible: root.details?.kind === "nvme" && root.details.dataRead !== undefined
            icon: "download"
            label: Tr.tr("Data read")
            value: Disks.human(root.details?.dataRead ?? 0)
        }

        InfoRow {
            visible: root.details?.kind === "nvme"
            icon: "power_settings_new"
            label: Tr.tr("Power cycles")
            subtext: Tr.tr("%1 of them without a clean shutdown").arg(root.number(root.details?.unsafeShutdowns))
            value: root.number(root.details?.powerCycles)
        }

        InfoRow {
            visible: root.details?.kind === "nvme"
            icon: "error"
            label: Tr.tr("Media errors")
            subtext: Tr.tr("Data it couldn't read back; should stay 0")
            value: root.number(root.details?.mediaErrors)
        }

        InfoRow {
            visible: root.h?.kind === "ata"
            icon: "grid_off"
            label: Tr.tr("Bad sectors")
            subtext: Tr.tr("Places it can't use any more; should stay 0")
            value: root.number(root.h?.badSectors)
        }

        // ---- Self-test ---------------------------------------------------------
        SectionHeader {
            visible: !!root.h
            text: Tr.tr("Self-test")
        }

        RowButton {
            readonly property bool running: (root.h?.selftestRemaining ?? -1) > 0 || root.h?.selftest === "inprogress"

            visible: !!root.h
            icon: running ? "stop_circle" : "speed"
            text: running ? Tr.tr("Stop the self-test") : Tr.tr("Run a short self-test")
            subtext: running ? Tr.tr("Running: %1% left").arg(root.h.selftestRemaining) : root.h?.selftest ? Tr.tr("Last result: %1. Takes about two minutes; the drive stays usable.").arg(root.h.selftest) : Tr.tr("Takes about two minutes; the drive stays usable")
            onClicked: Disks.run("selftest", [root.drive.id, running ? "abort" : "short"], Tr.tr("Run a drive self-test"))
        }

        RowButton {
            visible: !!root.h && !((root.h?.selftestRemaining ?? -1) > 0)
            icon: "manage_search"
            text: Tr.tr("Run an extended self-test")
            subtext: Tr.tr("Reads the whole drive: can take an hour or more")
            onClicked: Disks.run("selftest", [root.drive.id, "extended"], Tr.tr("Run a drive self-test"))
        }

        RowButton {
            visible: !!root.h
            icon: "refresh"
            text: Tr.tr("Read the health data again")
            onClicked: Disks.run("smart-update", [root.drive.id], Tr.tr("Read the drive's health"), () => root.load())
        }

        // ---- Every attribute (ATA) -----------------------------------------
        SectionHeader {
            visible: root.details?.kind === "ata"
            text: Tr.tr("All attributes")
        }

        Repeater {
            id: attrList

            model: root.details?.kind === "ata" ? root.details.attributes : []

            InfoRow {
                required property var modelData
                required property int index

                icon: modelData.failing ? "warning" : ""
                iconColour: Colours.palette.m3error
                label: `${modelData.id} · ${modelData.label}`
                subtext: Tr.tr("Score %1 (worst %2, fails at %3)").arg(modelData.value).arg(modelData.worst).arg(modelData.threshold)
                value: modelData.unit === 2 ? Tr.tr("%1 h").arg(Math.round(modelData.pretty / 3600000)) : modelData.unit === 4 ? `${Math.round(modelData.pretty / 1000 - 273.15)} °C` : String(modelData.pretty)
            }
        }
    }
}
