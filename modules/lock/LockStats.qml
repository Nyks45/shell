import QtQuick
import Quickshell
import Quickshell.Io
import M3Shapes
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services

Item {
    id: root

    readonly property bool hasGpu: Gpu.type !== GpuType.None
    readonly property real cpu: Cpu.percentage
    readonly property real temp: Cpu.temperature
    readonly property real mem: Memory.percentage
    readonly property real memGb: Memory.used / (1024 * 1024)
    readonly property real gpu: hasGpu ? Gpu.percentage : 0
    readonly property real gpuTemp: hasGpu ? Gpu.temperature : 0
    readonly property real diskTotalKib: Storage.primaryDisk?.total ?? 0
    readonly property real diskUsedKib: Storage.primaryDisk?.used ?? 0
    readonly property real disk: Storage.primaryDisk?.perc ?? Storage.percentage
    readonly property real netDown: NetworkUsage.downloadSpeed
    readonly property real netUp: NetworkUsage.uploadSpeed
    readonly property bool showSession: GlobalConfig.lock.enableSessionControls
    readonly property string sessionHelper: CUtils.fileExists("/usr/lib/caelestia/caelestia-session")
        ? "/usr/lib/caelestia/caelestia-session"
        : `${Quickshell.shellDir}/assets/caelestia-session`
    property var sessions: []
    property string currentSession: "hyprland.desktop"
    readonly property var currentSessionObj: {
        for (const s of sessions) {
            if (s.id === currentSession)
                return s;
        }
        return sessions.length > 0 ? sessions[0] : null;
    }
    readonly property string sessionLabel: currentSessionObj ? currentSessionObj.name : "Hyprland"

    Component.onCompleted: {
        if (showSession)
            sessionListProc.running = true;
    }

    function cycleSession(): void {
        if (sessions.length < 2)
            return;
        const idx = sessions.findIndex(s => s.id === currentSession);
        const next = sessions[(idx + 1) % sessions.length];
        if (!next)
            return;
        currentSession = next.id;
        sessionSetProc.running = false;
        sessionSetProc.command = [sessionHelper, "set", next.id];
        sessionSetProc.running = true;
    }

    Process {
        id: sessionListProc

        command: [root.sessionHelper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (Array.isArray(data.sessions))
                        root.sessions = data.sessions;
                    if (data.current)
                        root.currentSession = data.current;
                } catch (e) {}
            }
        }
    }

    Process {
        id: sessionSetProc
    }

    ServiceRef {
        service: root.visible ? Cpu : null
    }
    ServiceRef {
        service: root.visible ? Memory : null
    }
    ServiceRef {
        service: root.visible && root.hasGpu ? Gpu : null
    }
    ServiceRef {
        service: root.visible ? Storage : null
    }
    ServiceRef {
        service: root.visible ? NetworkUsage : null
    }

    function formatGb(kib: real): string {
        return (kib / (1024 * 1024)).toFixed(kib >= 100 * 1024 * 1024 ? 0 : 1) + "G";
    }

    function formatRate(bytesPerSec: real): string {
        return Units.formatBytes(Math.max(0, bytesPerSec), true);
    }

    function execSession(cmd: list<string>): void {
        if (!SessionManager.exec(cmd))
            Quickshell.execDetached(cmd);
    }

    Item {
        id: box

        readonly property real gap: 10
        readonly property real cardW: (width - gap * 2) / 3
        readonly property real sessionH: root.showSession ? 44 : 0
        readonly property real gridH: height - (root.showSession ? sessionH + gap : 0)
        readonly property real cardH: (gridH - gap) / 2

        width: NebulaTheme.lock.statsWidth
        height: NebulaTheme.lock.statsHeight
        scale: root.width / width
        transformOrigin: Item.TopLeft

        UsageCard {
            x: 0
            y: 0
            width: box.cardW
            height: box.cardH
            value: root.cpu
            colorFill: NebulaTheme.colors.primary
            onFill: NebulaTheme.colors.textOnPrimary
            chipShape: MaterialShape.Cookie6Sided
            icon: "memory"
            title: "CPU"
            valueText: `${Math.round(root.cpu * 100)}%`
        }

        UsageCard {
            x: box.cardW + box.gap
            y: 0
            width: box.cardW
            height: box.cardH
            value: root.mem
            colorFill: NebulaTheme.colors.secondary
            onFill: NebulaTheme.colors.textOnSecondary
            chipShape: MaterialShape.Cookie9Sided
            icon: "memory_alt"
            title: "RAM"
            valueText: `${root.memGb.toFixed(1)}G`
        }

        UsageCard {
            x: (box.cardW + box.gap) * 2
            y: 0
            width: box.cardW
            height: box.cardH
            value: root.gpu
            colorFill: NebulaTheme.colors.tertiary
            onFill: NebulaTheme.colors.textOnTertiary
            chipShape: MaterialShape.Clover4Leaf
            icon: "developer_board"
            title: "GPU"
            subText: root.hasGpu && root.gpuTemp > 0 ? `${Math.round(root.gpuTemp)}°` : ""
            valueText: root.hasGpu ? `${Math.round(root.gpu * 100)}%` : "--"
        }

        UsageCard {
            x: 0
            y: box.cardH + box.gap
            width: box.cardW
            height: box.cardH
            value: Math.max(0, Math.min(1, root.temp / 100))
            colorFill: NebulaTheme.colors.primary
            onFill: NebulaTheme.colors.textOnPrimary
            chipShape: MaterialShape.Sunny
            icon: "thermostat"
            title: "TEMP"
            valueText: `${Math.round(root.temp)}°`
        }

        UsageCard {
            x: box.cardW + box.gap
            y: box.cardH + box.gap
            width: box.cardW
            height: box.cardH
            value: root.disk
            colorFill: NebulaTheme.colors.secondary
            onFill: NebulaTheme.colors.textOnSecondary
            chipShape: MaterialShape.Pentagon
            icon: "storage"
            title: root.diskTotalKib > 0 ? root.formatGb(root.diskTotalKib) : "DISK"
            subText: root.diskUsedKib > 0 ? root.formatGb(root.diskUsedKib) : ""
            valueText: `${Math.round(root.disk * 100)}%`
        }

        UsageCard {
            x: (box.cardW + box.gap) * 2
            y: box.cardH + box.gap
            width: box.cardW
            height: box.cardH
            value: 0.04
            colorFill: NebulaTheme.colors.tertiary
            onFill: NebulaTheme.colors.textOnTertiary
            chipShape: MaterialShape.Circle
            icon: "swap_vert"
            title: "NET"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 4

                SpeedPill {
                    width: parent.width
                    arrow: "arrow_downward"
                    accent: NebulaTheme.colors.tertiary
                    text: root.formatRate(root.netDown)
                }

                SpeedPill {
                    width: parent.width
                    arrow: "arrow_upward"
                    accent: NebulaTheme.colors.secondary
                    text: root.formatRate(root.netUp)
                }
            }
        }

        Row {
            visible: root.showSession
            y: box.gridH + box.gap
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                id: sessionPill

                height: NebulaTheme.button.size
                implicitWidth: Math.min(240, sessionRow.implicitWidth + 24)
                radius: NebulaTheme.radius.full
                color: sessionMouse.pressed ? NebulaTheme.colors.surfaceContainerHighest
                    : sessionMouse.containsMouse ? NebulaTheme.colors.surfaceContainerHigh
                    : NebulaTheme.colors.surfaceContainer
                border.width: 1
                border.color: sessionMouse.containsMouse ? Qt.alpha(NebulaTheme.colors.primary, 0.45) : Qt.alpha(NebulaTheme.colors.textOnSurface, 0.08)

                Row {
                    id: sessionRow

                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "desktop_windows"
                        font.family: NebulaTheme.font.icons
                        font.pixelSize: 18
                        color: NebulaTheme.colors.primary
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sessionLabel
                        font.family: NebulaTheme.font.family
                        font.pixelSize: NebulaTheme.font.normal
                        font.weight: Font.Medium
                        color: NebulaTheme.colors.textOnSurface
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.sessions.length > 1
                        text: "swap_horiz"
                        font.family: NebulaTheme.font.icons
                        font.pixelSize: 16
                        color: Qt.alpha(NebulaTheme.colors.textOnSurface, 0.55)
                    }
                }

                MouseArea {
                    id: sessionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.sessions.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.cycleSession()
                }
            }

            NebulaIconButton {
                icon: Config.session.icons.logout
                onClicked: root.execSession(Config.session.commands.logout)
            }
            NebulaIconButton {
                icon: Config.session.icons.sleep
                onClicked: root.execSession(Config.session.commands.sleep)
            }
            NebulaIconButton {
                icon: Config.session.icons.reboot
                onClicked: root.execSession(Config.session.commands.reboot)
            }
            NebulaIconButton {
                icon: Config.session.icons.shutdown
                onClicked: root.execSession(Config.session.commands.shutdown)
            }
        }
    }
}
