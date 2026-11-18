pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.services

// The task manager's window: an overlay layer over the focused screen (above fullscreen apps),
// taking the keyboard so it works whatever has hung. Click outside or Esc to close.
StyledWindow {
    id: win

    signal closeRequested

    property string page: "processes"

    // A minute of readings, kept while the window is open (each page reads them)
    property var histories: ({})

    function history(key: string): CircularBuffer {
        if (!histories[key])
            histories[key] = bufferComponent.createObject(win);
        return histories[key];
    }

    function bytes(v: real): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (Math.abs(v) >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return `${v.toFixed(i === 0 ? 0 : v < 10 ? 2 : v < 100 ? 1 : 0)} ${units[i]}`;
    }

    function rate(v: real): string {
        return `${bytes(v)}/s`;
    }

    function percent(v: real): string {
        return `${(v * 100).toFixed(v < 0.1 ? 1 : 0)}%`;
    }

    screen: Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
    name: "taskmanager"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Component {
        id: bufferComponent

        CircularBuffer {
            capacity: 60
        }
    }

    ServiceRef {
        service: SystemStats
    }

    ServiceRef {
        service: Gpu
    }

    Connections {
        function onUpdated(): void {
            win.history("cpu").push(SystemStats.cpu);
            const cores = SystemStats.cores;
            for (let i = 0; i < cores.length; i++)
                win.history(`core${i}`).push(cores[i]);
            win.history("memory").push(SystemStats.memTotal > 0 ? SystemStats.memUsed / SystemStats.memTotal : 0);
            win.history("swap").push(SystemStats.swapTotal > 0 ? SystemStats.swapUsed / SystemStats.swapTotal : 0);
            for (const d of SystemStats.disks) {
                win.history(`disk:${d.name}`).push(d.busy);
                win.history(`diskr:${d.name}`).push(d.read);
                win.history(`diskw:${d.name}`).push(d.write);
            }
            for (const n of SystemStats.networks) {
                win.history(`netr:${n.name}`).push(n.rx);
                win.history(`nett:${n.name}`).push(n.tx);
            }
            win.history("gpu").push(Gpu.percentage);
            win.history("vram").push(Gpu.memoryTotal > 0 ? Gpu.memoryUsed / Gpu.memoryTotal : 0);
        }

        target: SystemStats
    }

    // The dimmed screen: a click on it closes
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: win.closeRequested()
        }
    }

    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(1240, parent.width - 64)
        height: Math.min(800, parent.height - 64)
        radius: Tokens.rounding.large
        color: Colours.palette.m3surface
        focus: true

        Keys.onEscapePressed: win.closeRequested()
        Keys.onPressed: event => {
            if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) {
                win.page = "processes";
                processesLoader.item?.focusSearch();
                event.accepted = true;
            } else if (event.modifiers & Qt.ControlModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                win.page = ["processes", "performance", "services"][event.key - Qt.Key_1];
                event.accepted = true;
            }
        }

        // (clicks inside don't close)
        MouseArea {
            anchors.fill: parent
            onPressed: card.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // Title and pages
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "monitoring"
                    color: Colours.palette.m3primary
                    font: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.rightMargin: Tokens.spacing.large
                    text: qsTr("Task manager")
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                Repeater {
                    model: [
                        {
                            id: "processes",
                            label: qsTr("Processes"),
                            icon: "apps"
                        },
                        {
                            id: "performance",
                            label: qsTr("Performance"),
                            icon: "speed"
                        },
                        {
                            id: "services",
                            label: qsTr("Services"),
                            icon: "settings_applications"
                        }
                    ]

                    TabButton {
                        required property var modelData

                        label: modelData.label
                        icon: modelData.icon
                        selected: win.page === modelData.id
                        onClicked: win.page = modelData.id
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: qsTr("Up %1").arg(win.uptimeText(SystemStats.uptime))
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3onSurfaceVariant
                }

                TabButton {
                    icon: "close"
                    onClicked: win.closeRequested()
                }
            }

            Loader {
                id: processesLoader

                Layout.fillWidth: true
                Layout.fillHeight: true
                active: win.page === "processes"
                visible: active

                sourceComponent: ProcessesPage {
                    window: win
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: win.page === "performance"
                visible: active

                sourceComponent: PerformancePage {
                    window: win
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: win.page === "services"
                visible: active

                sourceComponent: ServicesPage {
                    window: win
                }
            }
        }
    }

    function uptimeText(s: real): string {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d}d ${h}h ${m}m` : h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
