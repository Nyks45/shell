pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Dashboard > Performance (the island's page size): a card each for the processor, graphics card,
// memory and storage (gauge, temperature or space used, the device), the network's speed under them
Item {
    id: root

    readonly property bool hasGpu: Gpu.type !== GpuType.None

    // A device's name without the maker's boilerplate ("AMD Ryzen 5 7600 6-Core Processor" ->
    // "Ryzen 5 7600", "NVIDIA GeForce RTX 4070 Ti SUPER" -> "RTX 4070 Ti SUPER")
    function shortName(n: string): string {
        return (n ?? "").replace(/\(R\)|\(TM\)|®|™/gi, "").replace(/\b(AMD|Intel|NVIDIA|GeForce|Radeon(?= RX)|Core(?= i\d)|Corporation)\b/gi, "").replace(/\s+\d+-Core Processor|\s+Processor|\s+with Radeon.*$|\s+CPU @.*$/gi, "").replace(/\s+\d+-\S*$/, "").replace(/\s+/g, " ").trim();
    }

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Gpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    ServiceRef {
        service: NetworkUsage
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Gauge {
                icon: "memory"
                label: Tr.tr("Processor")
                value: Cpu.percentage
                detailIcon: "device_thermostat"
                detail: Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)}°C` : ""
                sub: root.shortName(Cpu.name)
            }

            Gauge {
                visible: root.hasGpu
                icon: "developer_board"
                label: Tr.tr("Graphics")
                value: Gpu.percentage
                detailIcon: "device_thermostat"
                detail: Gpu.temperature > 0 ? `${Math.round(Gpu.temperature)}°C` : ""
                sub: root.shortName(Gpu.name)
                colour: Colours.palette.m3secondary
            }

            Gauge {
                icon: "memory_alt"
                label: Tr.tr("Memory")
                value: Memory.percentage
                detailIcon: "data_usage"
                detail: Units.formatKibUsage(Memory.used, Memory.total)
                sub: Tr.tr("RAM")
                colour: Colours.palette.m3tertiary
            }

            Gauge {
                icon: "hard_drive"
                label: Tr.tr("Storage")
                value: Storage.primaryDisk?.perc ?? Storage.percentage
                detailIcon: "data_usage"
                detail: Storage.primaryDisk ? Units.formatKibUsage(Storage.primaryDisk.used, Storage.primaryDisk.total) : ""
                sub: Storage.primaryDisk?.mount ?? ""
                colour: Colours.palette.m3secondary
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.large

            Speed {
                icon: "download"
                text: Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true)
            }

            Speed {
                icon: "upload"
                text: Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true)
            }
        }
    }

    // A card: what it is, a gauge, and its numbers (temperature or space used, the device)
    component Gauge: StyledRect {
        id: gauge

        property string icon
        property string label
        property real value
        property string detailIcon
        property string detail
        property string sub
        property color colour: Colours.palette.m3primary

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: 2

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: gauge.icon
                    color: gauge.colour
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: gauge.label
                    font: Tokens.font.label.medium
                }
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.preferredWidth: height
                Layout.maximumHeight: 72

                CircularProgress {
                    anchors.fill: parent
                    value: gauge.value
                    fgColour: gauge.colour
                    strokeWidth: 6
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Strings.percentOne(gauge.value)
                    font: Tokens.font.title.small
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: gauge.detail !== ""
                spacing: 2

                MaterialIcon {
                    text: gauge.detailIcon
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: gauge.detail
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }

            // The device, whole: shrinks to fit rather than being cut
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: gauge.sub || " "
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                fontSizeMode: Text.HorizontalFit
                minimumPointSize: 6
                elide: Text.ElideRight
            }
        }
    }

    component Speed: RowLayout {
        property string icon
        property string text

        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            text: parent.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: parent.text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
