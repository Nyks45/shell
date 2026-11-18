pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

// Each device's last minute: CPU (and each core), memory, every disk and network interface,
// the GPU. Pick one on the left to see it large with its details.
Item {
    id: root

    required property var window

    property string selected: "cpu"

    // The devices, rebuilt only when disks or interfaces come or go (not every reading)
    property var diskNames: []
    property var netNames: []

    function refreshNames(): void {
        const d = SystemStats.disks.map(x => x.name), n = SystemStats.networks.map(x => x.name);
        if (JSON.stringify(d) !== JSON.stringify(diskNames))
            diskNames = d;
        if (JSON.stringify(n) !== JSON.stringify(netNames))
            netNames = n;
    }

    function disk(name: string): var {
        return SystemStats.disks.find(x => x.name === name) ?? ({});
    }

    function net(name: string): var {
        return SystemStats.networks.find(x => x.name === name) ?? ({});
    }

    Component.onCompleted: refreshNames()

    Connections {
        function onUpdated(): void {
            root.refreshNames();
        }

        target: SystemStats
    }

    ServiceRef {
        service: Cpu
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // The devices
        Flickable {
            Layout.preferredWidth: 270
            Layout.fillHeight: true
            contentHeight: devices.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: devices

                width: parent.width
                spacing: Tokens.spacing.small

                Device {
                    key: "cpu"
                    title: qsTr("CPU")
                    value: `${root.window.percent(SystemStats.cpu)}  ${(SystemStats.frequency / 1000).toFixed(2)} GHz`
                    buffer: root.window.history("cpu")
                }

                Device {
                    key: "memory"
                    title: qsTr("Memory")
                    value: `${root.window.bytes(SystemStats.memUsed)} / ${root.window.bytes(SystemStats.memTotal)}`
                    buffer: root.window.history("memory")
                }

                Repeater {
                    model: root.diskNames

                    Device {
                        required property string modelData

                        key: `disk:${modelData}`
                        title: qsTr("Disk %1").arg(modelData)
                        value: `${root.window.percent(root.disk(modelData).busy ?? 0)}`
                        buffer: root.window.history(`disk:${modelData}`)
                    }
                }

                Repeater {
                    model: root.netNames

                    Device {
                        required property string modelData

                        key: `net:${modelData}`
                        title: root.net(modelData).wireless ? qsTr("Wi-Fi %1").arg(modelData) : qsTr("Ethernet %1").arg(modelData)
                        value: `↓ ${root.window.rate(root.net(modelData).rx ?? 0)}  ↑ ${root.window.rate(root.net(modelData).tx ?? 0)}`
                        buffer: root.window.history(`netr:${modelData}`)
                        buffer2: root.window.history(`nett:${modelData}`)
                        rateScale: true
                    }
                }

                Device {
                    visible: Gpu.type !== GpuType.None
                    key: "gpu"
                    title: qsTr("GPU")
                    value: `${root.window.percent(Gpu.percentage)}  ${Gpu.temperature > 0 ? Math.round(Gpu.temperature) + " °C" : ""}`
                    buffer: root.window.history("gpu")
                }
            }
        }

        // The selected device, large
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer

            Loader {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                sourceComponent: root.selected === "cpu" ? cpuDetail : root.selected === "memory" ? memoryDetail : root.selected === "gpu" ? gpuDetail : root.selected.startsWith("disk:") ? diskDetail : netDetail
            }
        }
    }

    Component {
        id: cpuDetail

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Heading {
                title: qsTr("CPU")
                subtitle: Cpu.name
            }

            // Each logical core
            GridLayout {
                id: grid

                readonly property int count: SystemStats.cores.length

                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: count <= 4 ? count : count <= 8 ? 4 : count <= 16 ? 4 : count <= 24 ? 6 : 8
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small

                Repeater {
                    model: grid.count

                    Graph {
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        buffer: root.window.history(`core${index}`)
                        label: qsTr("CPU %1").arg(index)
                        compact: true
                    }
                }
            }

            Stats {
                model: [[qsTr("Utilisation"), root.window.percent(SystemStats.cpu)], [qsTr("Speed"), `${(SystemStats.frequency / 1000).toFixed(2)} GHz`], [qsTr("Temperature"), Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)} °C` : "—"], [qsTr("Logical cores"), SystemStats.cores.length], [qsTr("Processes"), Processes.total > 0 ? Processes.total : "—"], [qsTr("Up time"), root.window.uptimeText(SystemStats.uptime)]]
            }
        }
    }

    Component {
        id: memoryDetail

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Heading {
                title: qsTr("Memory")
                subtitle: root.window.bytes(SystemStats.memTotal)
            }

            Graph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buffer: root.window.history("memory")
                label: qsTr("Memory in use")
            }

            Graph {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                visible: SystemStats.swapTotal > 0
                buffer: root.window.history("swap")
                label: qsTr("Swap")
            }

            Stats {
                model: [[qsTr("In use"), root.window.bytes(SystemStats.memUsed)], [qsTr("Available"), root.window.bytes(SystemStats.memTotal - SystemStats.memUsed)], [qsTr("Cached"), root.window.bytes(SystemStats.memCached)], [qsTr("Buffers"), root.window.bytes(SystemStats.memBuffers)], [qsTr("Swap used"), `${root.window.bytes(SystemStats.swapUsed)} / ${root.window.bytes(SystemStats.swapTotal)}`]]
            }
        }
    }

    Component {
        id: diskDetail

        ColumnLayout {
            readonly property string name: root.selected.slice(5)
            readonly property var d: root.disk(name)

            spacing: Tokens.spacing.medium

            Heading {
                title: qsTr("Disk %1").arg(parent.name)
                subtitle: parent.d.model ?? ""
            }

            Graph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buffer: root.window.history(`disk:${parent.name}`)
                label: qsTr("Active time")
            }

            Graph {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                buffer: root.window.history(`diskr:${parent.name}`)
                buffer2: root.window.history(`diskw:${parent.name}`)
                rateScale: true
                label: qsTr("Read (solid) and write speed")
            }

            Stats {
                model: [[qsTr("Active time"), root.window.percent(parent.d.busy ?? 0)], [qsTr("Read"), root.window.rate(parent.d.read ?? 0)], [qsTr("Write"), root.window.rate(parent.d.write ?? 0)], [qsTr("Removable"), parent.d.removable ? qsTr("Yes") : qsTr("No")]]
            }
        }
    }

    Component {
        id: netDetail

        ColumnLayout {
            readonly property string name: root.selected.slice(4)
            readonly property var n: root.net(name)

            spacing: Tokens.spacing.medium

            Heading {
                title: parent.n.wireless ? qsTr("Wi-Fi") : qsTr("Ethernet")
                subtitle: parent.name
            }

            Graph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buffer: root.window.history(`netr:${parent.name}`)
                buffer2: root.window.history(`nett:${parent.name}`)
                rateScale: true
                label: qsTr("Receive (solid) and send")
            }

            Stats {
                model: [[qsTr("Receiving"), root.window.rate(parent.n.rx ?? 0)], [qsTr("Sending"), root.window.rate(parent.n.tx ?? 0)], [qsTr("Received"), root.window.bytes(parent.n.rxTotal ?? 0)], [qsTr("Sent"), root.window.bytes(parent.n.txTotal ?? 0)]]
            }
        }
    }

    Component {
        id: gpuDetail

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Heading {
                title: qsTr("GPU")
                subtitle: Gpu.name
            }

            Graph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buffer: root.window.history("gpu")
                label: qsTr("Utilisation")
            }

            Graph {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                visible: Gpu.memoryTotal > 0
                buffer: root.window.history("vram")
                label: qsTr("Video memory")
            }

            Stats {
                model: [[qsTr("Utilisation"), root.window.percent(Gpu.percentage)], [qsTr("Temperature"), Gpu.temperature > 0 ? `${Math.round(Gpu.temperature)} °C` : "—"], [qsTr("Video memory"), Gpu.memoryTotal > 0 ? `${root.window.bytes(Gpu.memoryUsed)} / ${root.window.bytes(Gpu.memoryTotal)}` : "—"]]
            }
        }
    }

    // A device on the left: name, current value, a small graph
    component Device: StyledRect {
        id: device

        property string key
        property string title
        property string value
        property CircularBuffer buffer
        property CircularBuffer buffer2
        property bool rateScale

        Layout.fillWidth: true
        implicitHeight: 64
        radius: Tokens.rounding.medium
        color: root.selected === key ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: root.selected = device.key
        }

        SparklineItem {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            width: 90
            line1: device.buffer
            line2: device.buffer2
            line1Color: Colours.palette.m3primary
            line2Color: Colours.palette.m3tertiary
            line1FillAlpha: 0.25
            line2FillAlpha: 0
            historyLength: 60
            lineWidth: 1.5
            maxValue: device.rateScale ? Math.max(1024, device.buffer?.maximum ?? 0, device.buffer2?.maximum ?? 0) : 1
        }

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium
            width: parent.width - 120

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: device.title
                font: Tokens.font.label.large
                color: Colours.palette.m3onSurface
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: device.value
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    component Heading: RowLayout {
        property string title
        property string subtitle

        Layout.fillWidth: true

        StyledText {
            text: parent.title
            font: Tokens.font.headline.small
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: parent.subtitle
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // A graph of the last minute, with a label and grid frame
    component Graph: StyledRect {
        id: graph

        property CircularBuffer buffer
        property CircularBuffer buffer2
        property string label
        property bool compact
        property bool rateScale

        radius: Tokens.rounding.small
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3primary, 0.35)

        SparklineItem {
            anchors.fill: parent
            anchors.margins: 1
            line1: graph.buffer
            line2: graph.buffer2
            line1Color: Colours.palette.m3primary
            line2Color: Colours.palette.m3tertiary
            line1FillAlpha: 0.2
            line2FillAlpha: 0
            historyLength: 60
            lineWidth: graph.compact ? 1.2 : 2
            maxValue: graph.rateScale ? Math.max(1024, graph.buffer?.maximum ?? 0, graph.buffer2?.maximum ?? 0) * 1.1 : 1
        }

        StyledText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            text: graph.label + (graph.rateScale ? `  (max ${root.window.rate(Math.max(graph.buffer?.maximum ?? 0, graph.buffer2?.maximum ?? 0))})` : "")
            font: graph.compact ? Tokens.font.label.small : Tokens.font.label.medium
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    // Name–value pairs under a graph
    component Stats: Flow {
        property var model: []

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraLarge

        Repeater {
            model: parent.model

            Column {
                required property var modelData

                StyledText {
                    text: parent.modelData[0]
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: String(parent.modelData[1])
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }
}
