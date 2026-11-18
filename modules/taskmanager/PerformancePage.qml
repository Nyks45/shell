pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
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

    // Bytes as GiB, short: 4.5, 16
    function gib(v, digits): string {
        const g = v / 1073741824;
        return g.toFixed(digits ?? (g < 10 ? 1 : 0));
    }

    function disk(name: string): var {
        return SystemStats.disks.find(x => x.name === name) ?? ({});
    }

    function net(name: string): var {
        return SystemStats.networks.find(x => x.name === name) ?? ({});
    }

    Component.onCompleted: refreshNames()

    // Hardware details (read once, or now and then while shown)
    property var cpuInfo: ({})
    property var diskInfo: ({}) // name -> {size, model, rota, tran, parts: [{name, fstype, mounts}]}
    property var netInfo: ({}) // name -> {addrs, mac, speed}
    property var gpuInfo: ({})

    Process {
        command: ["env", "LC_ALL=C", "lscpu", "-J"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = {};
                    for (const x of JSON.parse(text).lscpu)
                        d[x.field.replace(":", "")] = x.data;
                    root.cpuInfo = d;
                } catch (e) {}
            }
        }
    }

    Process {
        command: ["lsblk", "-J", "-b", "-o", "NAME,SIZE,MODEL,ROTA,TRAN,FSTYPE,MOUNTPOINTS"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {};
                    const walk = (dev, parts) => {
                        for (const c of dev.children ?? []) {
                            const mounts = (c.mountpoints ?? []).filter(m => m);
                            if (c.fstype || mounts.length)
                                parts.push({
                                    name: c.name,
                                    fstype: c.fstype ?? "",
                                    mounts: mounts
                                });
                            walk(c, parts);
                        }
                    };
                    for (const d of JSON.parse(text).blockdevices) {
                        const parts = [];
                        walk(d, parts);
                        map[d.name] = {
                            size: d.size,
                            model: d.model ?? "",
                            rota: d.rota,
                            tran: d.tran ?? "",
                            parts: parts
                        };
                    }
                    root.diskInfo = map;
                } catch (e) {}
            }
        }
    }

    Process {
        id: netProc

        command: ["sh", "-c", "ip -j addr show; echo; for i in /sys/class/net/*; do echo \"$(basename $i) $(cat $i/speed 2>/dev/null)\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [json, ...speeds] = text.split("\n").filter(l => l.trim() !== "");
                    const map = {};
                    for (const i of JSON.parse(json))
                        map[i.ifname] = {
                            addrs: (i.addr_info ?? []).map(a => `${a.local}/${a.prefixlen}`),
                            mac: i.address ?? "",
                            speed: 0
                        };
                    for (const l of speeds) {
                        const [name, speed] = l.split(" ");
                        if (map[name])
                            map[name].speed = parseInt(speed) || 0;
                    }
                    root.netInfo = map;
                } catch (e) {}
            }
        }
    }

    Process {
        id: gpuProc

        command: ["nvidia-smi", "--query-gpu=driver_version,power.draw,power.limit,clocks.gr,clocks.mem,fan.speed,utilization.encoder,utilization.decoder,pcie.link.gen.current,pcie.link.width.current", "--format=csv,noheader,nounits"]
        running: root.selected === "gpu"
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",").map(x => x.trim());
                if (f.length >= 10)
                    root.gpuInfo = {
                        driver: f[0],
                        power: f[1],
                        powerLimit: f[2],
                        clock: f[3],
                        memClock: f[4],
                        fan: f[5],
                        encoder: f[6],
                        decoder: f[7],
                        pcie: `Gen ${f[8]} ×${f[9]}`
                    };
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 2000
        onTriggered: {
            if (root.selected === "gpu" && !gpuProc.running)
                gpuProc.running = true;
            if (root.selected.startsWith("net:") && !netProc.running)
                netProc.running = true;
        }
    }

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
                    value: `${root.gib(SystemStats.memUsed)} / ${root.gib(SystemStats.memTotal)} GiB · ${root.window.percent(SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0)}`
                    buffer: root.window.history("memory")
                }

                Repeater {
                    model: root.diskNames

                    Device {
                        required property string modelData

                        key: `disk:${modelData}`
                        title: qsTr("Disk")
                        tag: `${modelData}${root.diskInfo[modelData]?.size ? " · " + root.gib(root.diskInfo[modelData].size, 0) + " GiB" : ""}`
                        value: `${root.window.percent(root.disk(modelData).busy ?? 0)}`
                        buffer: root.window.history(`disk:${modelData}`)
                    }
                }

                Repeater {
                    model: root.netNames

                    Device {
                        required property string modelData

                        key: `net:${modelData}`
                        title: root.net(modelData).wireless ? qsTr("Wi-Fi") : qsTr("Ethernet")
                        tag: modelData
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
                    // (load, and video memory like the memory tile)
                    value: Gpu.memoryTotal > 0 ? `${root.window.percent(Gpu.percentage)} · ${root.gib(Gpu.memoryUsed)} / ${root.gib(Gpu.memoryTotal)} GiB` : `${root.window.percent(Gpu.percentage)}  ${Gpu.temperature > 0 ? Math.round(Gpu.temperature) + " °C" : ""}`
                    buffer: root.window.history("gpu")
                    buffer2: Gpu.memoryTotal > 0 ? root.window.history("vram") : null
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
                subtitle: root.cpuInfo["Model name"] ?? Cpu.name
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
                model: {
                    const c = root.cpuInfo;
                    const cores = (parseInt(c["Core(s) per socket"]) || 0) * (parseInt(c["Socket(s)"]) || 1);
                    const max = parseFloat(c["CPU max MHz"]) || 0;
                    return [[qsTr("Utilisation"), root.window.percent(SystemStats.cpu)], [qsTr("Speed"), `${(SystemStats.frequency / 1000).toFixed(2)} GHz`], [qsTr("Maximum speed"), max > 0 ? `${(max / 1000).toFixed(2)} GHz` : "—"], [qsTr("Temperature"), Cpu.temperature > 0 ? `${Math.round(Cpu.temperature)} °C` : "—"], [qsTr("Cores"), cores || "—"], [qsTr("Logical processors"), SystemStats.cores.length], [qsTr("Sockets"), c["Socket(s)"] ?? "—"], [qsTr("Virtualisation"), c["Virtualization"] ?? qsTr("Off")], [qsTr("L1 cache"), (c["L1d cache"] ?? "—").replace(/ \(.*\)/, "")], [qsTr("L2 cache"), (c["L2 cache"] ?? "—").replace(/ \(.*\)/, "")], [qsTr("L3 cache"), (c["L3 cache"] ?? "—").replace(/ \(.*\)/, "")], [qsTr("Up time"), root.window.uptimeText(SystemStats.uptime)]];
                }
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
                model: {
                    const i = root.diskInfo[parent.name] ?? {};
                    const kind = parent.name.startsWith("nvme") ? "NVMe SSD" : i.rota === false ? "SSD" : i.rota ? "HDD" : "—";
                    const mounts = (i.parts ?? []).flatMap(p => p.mounts).filter(m => !m.startsWith("/.") && m !== "[SWAP]");
                    return [[qsTr("Active time"), root.window.percent(parent.d.busy ?? 0)], [qsTr("Read"), root.window.rate(parent.d.read ?? 0)], [qsTr("Write"), root.window.rate(parent.d.write ?? 0)], [qsTr("Capacity"), i.size ? root.window.bytes(i.size) : "—"], [qsTr("Type"), `${kind}${i.tran ? " (" + i.tran.toUpperCase() + ")" : ""}`], [qsTr("File systems"), [...new Set((i.parts ?? []).map(p => p.fstype).filter(f => f))].join(", ") || "—"], [qsTr("Mounted at"), mounts.slice(0, 4).join(", ") || "—"], [qsTr("Removable"), parent.d.removable ? qsTr("Yes") : qsTr("No")]];
                }
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
                model: {
                    const i = root.netInfo[parent.name] ?? {};
                    const v4 = (i.addrs ?? []).filter(a => !a.includes(":"));
                    const v6 = (i.addrs ?? []).filter(a => a.includes(":"));
                    return [[qsTr("Receiving"), root.window.rate(parent.n.rx ?? 0)], [qsTr("Sending"), root.window.rate(parent.n.tx ?? 0)], [qsTr("Received"), root.window.bytes(parent.n.rxTotal ?? 0)], [qsTr("Sent"), root.window.bytes(parent.n.txTotal ?? 0)], [qsTr("Link speed"), i.speed > 0 ? (i.speed >= 1000 ? `${i.speed / 1000} Gbps` : `${i.speed} Mbps`) : "—"], [qsTr("IPv4 address"), v4.join(", ") || "—"], [qsTr("IPv6 address"), v6[0] ?? "—"], [qsTr("Hardware address"), i.mac || "—"]];
                }
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
                model: {
                    const g = root.gpuInfo;
                    return [[qsTr("Utilisation"), root.window.percent(Gpu.percentage)], [qsTr("Video memory"), Gpu.memoryTotal > 0 ? `${root.window.bytes(Gpu.memoryUsed)} / ${root.window.bytes(Gpu.memoryTotal)}` : "—"], [qsTr("Temperature"), Gpu.temperature > 0 ? `${Math.round(Gpu.temperature)} °C` : "—"], [qsTr("Power"), g.power ? `${Math.round(g.power)} W / ${Math.round(g.powerLimit)} W` : "—"], [qsTr("Clock"), g.clock ? `${g.clock} MHz` : "—"], [qsTr("Memory clock"), g.memClock ? `${g.memClock} MHz` : "—"], [qsTr("Fan"), g.fan ? `${g.fan}%` : "—"], [qsTr("Video encoder"), g.encoder ? `${g.encoder}%` : "—"], [qsTr("Video decoder"), g.decoder ? `${g.decoder}%` : "—"], [qsTr("PCIe link"), g.pcie ?? "—"], [qsTr("Driver"), g.driver ?? "—"]];
                }
            }
        }
    }

    // A device on the left: name, current value, its last minute drawn behind them
    component Device: StyledRect {
        id: device

        property string key
        property string title
        property string tag
        property string value
        property CircularBuffer buffer
        property CircularBuffer buffer2
        property bool rateScale

        Layout.fillWidth: true
        implicitHeight: 66
        radius: Tokens.rounding.medium
        color: root.selected === key ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        clip: true

        SparklineItem {
            anchors.fill: parent
            anchors.topMargin: parent.height * 0.3
            opacity: 0.55
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

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: root.selected = device.key
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium

            Row {
                width: parent.width
                spacing: Tokens.spacing.small

                StyledText {
                    id: deviceTitle

                    text: device.title
                    font: Tokens.font.label.large
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    anchors.baseline: deviceTitle.baseline
                    width: parent.width - deviceTitle.implicitWidth - parent.spacing
                    visible: device.tag !== ""
                    elide: Text.ElideRight
                    text: device.tag
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: device.value
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    component Heading: RowLayout {
        property string title
        property string subtitle

        Layout.fillWidth: true

        StyledText {
            Layout.maximumWidth: parent.width * 0.5
            elide: Text.ElideRight
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
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            elide: Text.ElideRight
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
                id: stat

                required property var modelData
                // (long values, like addresses or mount points, are cut with "…")
                readonly property real cap: 280

                width: Math.min(cap, Math.max(statKey.implicitWidth, statValue.implicitWidth))

                StyledText {
                    id: statKey

                    width: parent.width
                    elide: Text.ElideRight
                    text: stat.modelData[0]
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    id: statValue

                    width: parent.width
                    elide: Text.ElideRight
                    text: String(stat.modelData[1])
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }
}
