import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // Hyprland plugins loaded right now (the Plugins page manages them)
    property int pluginCount

    property string quickshellVersion
    property string cliVersion
    property string hyprVersion
    property string uptime
    // Hardware: processor, graphics, memory, storage (lines from hwProc)
    property var hw: ({})

    function formattedStorage(): string {
        const [size, used] = (root.hw.disk ?? "").split(" ").map(Number);
        if (!size)
            return "";
        const gb = b => b >= 1e12 ? `${(b / 1e12).toFixed(2)} TB` : `${Math.round(b / 1e9)} GB`;
        return Tr.tr("%1 used of %2 (system drive)").arg(gb(used)).arg(gb(size));
    }

    function copySystemInfo(): void {
        const lines = [
            `Computer name: ${SysInfo.hostname}`,
            SysInfo.device ? `Device: ${SysInfo.device}` : "",
            `Operating system: ${SysInfo.osPrettyName || SysInfo.osName}`,
            `Kernel: ${SysInfo.kernel}`,
            SysInfo.firmware ? `Firmware: ${SysInfo.firmware}` : "",
            root.uptime ? `Uptime: ${root.uptime}` : "",
            root.hw.cpu ? `Processor: ${root.hw.cpu} (${root.hw.cores} threads)` : "",
            ...(root.hw.gpus ?? []).map((g, i) => `${i === 0 ? "Graphics" : "Graphics " + (i + 1)}: ${g}`),
            root.hw.mem ? `Memory: ${(parseInt(root.hw.mem) / 1048576).toFixed(1)} GiB` : "",
            root.formattedStorage() ? `Storage: ${root.formattedStorage()}` : "",
            `Shell: ${CUtils.version || "unknown"}`,
            root.cliVersion ? `Command-line tool: ${root.cliVersion}` : "",
            root.quickshellVersion ? `Quickshell: ${root.quickshellVersion}` : "",
            `Qt: ${CUtils.qtVersion || "unknown"}`,
            root.hyprVersion ? `Hyprland: ${root.hyprVersion}` : "",
            `Loaded plugins: ${root.pluginCount}`
        ].filter(Boolean).join("\n");
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | wl-copy", "sh", lines]);
        Toaster.toast(Tr.tr("System information copied"), "", "content_copy");
    }

    title: Tr.tr("About")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // e.g. "Quickshell 0.3.0 (revision ...)"
        Process {
            running: true
            command: ["quickshell", "--version"]
            stdout: StdioCollector {
                onStreamFinished: root.quickshellVersion = text.trim().split(" ")[1] ?? ""
            }
        }

        // Parsed from the caelestia CLI's package listing; the sh wrapper avoids a
        // warning when the (optional) CLI isn't installed
        Process {
            running: true
            command: ["sh", "-c", "caelestia --version 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/caelestia-cli\S*\s+(\d+(?:\.\d+)*)/);
                    root.cliVersion = m ? m[1] : "";
                }
            }
        }

        Process {
            id: hwProc

            running: true
            command: ["sh", "-c", `
echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo "cores=$(nproc)"
lspci 2>/dev/null | grep -Ei 'vga|3d controller|display controller' | sed -E 's/^[0-9a-f:.]+ [^:]+: //' | while read -r g; do echo "gpu=$g"; done
echo "mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
df -B1 --output=size,used / | tail -1 | awk '{print "disk=" $1 " " $2}'
echo "up=$(uptime -p 2>/dev/null | sed 's/^up *//')"
echo "hypr=$(hyprctl version 2>/dev/null | head -n1 | awk '{print $2}')"
`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const hw = {
                        gpus: []
                    };
                    for (const line of text.split("\n")) {
                        const i = line.indexOf("=");
                        if (i < 0)
                            continue;
                        const k = line.slice(0, i), v = line.slice(i + 1).trim();
                        if (k === "gpu")
                            hw.gpus.push(v.replace(/\s*\(rev [0-9a-f]+\)$/i, "").replace(/\s*\[[0-9a-f]{4}:[0-9a-f]{4}\]/gi, "").replace(/Advanced Micro Devices, Inc\.\s*\[AMD\/ATI\]\s*/g, "AMD ").replace(/^(NVIDIA|Advanced Micro Devices, Inc\.|Intel) Corporation\s+/, "$1 "));
                        else if (k === "up")
                            root.uptime = v;
                        else if (k === "hypr")
                            root.hyprVersion = v;
                        else
                            hw[k] = v;
                    }
                    root.hw = hw;
                }
            }
        }

        // Hero
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: hero

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: Tokens.spacing.small

                AnimatedLogo {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: "Caelestia"
                    font: Tokens.font.headline.builders.large.width(110).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: CUtils.version ? `v${CUtils.version}` : "…"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                }
            }
        }

        // System
        SectionHeader {
            text: Tr.tr("System")
        }

        InfoRow {
            label: Tr.tr("Computer name")
            value: SysInfo.hostname
        }

        InfoRow {
            label: Tr.trCtx("Device", "system model name")
            value: SysInfo.device
        }

        InfoRow {
            label: Tr.tr("Operating system")
            value: SysInfo.osPrettyName || SysInfo.osName
        }

        InfoRow {
            label: Tr.tr("Kernel")
            value: SysInfo.kernel
        }

        InfoRow {
            // TRANSLATORS: BIOS or UEFI firmware version
            label: Tr.tr("Firmware")
            value: SysInfo.firmware
        }

        InfoRow {
            visible: !!root.uptime
            label: Tr.tr("Uptime")
            value: root.uptime
        }

        // Hardware
        SectionHeader {
            text: Tr.tr("Hardware")
        }

        InfoRow {
            label: Tr.tr("Processor")
            value: root.hw.cpu ?? ""
            subtext: root.hw.cores ? Tr.tr("%1 threads").arg(root.hw.cores) : ""
        }

        Repeater {
            model: root.hw.gpus ?? []

            InfoRow {
                required property string modelData
                required property int index

                label: index === 0 ? Tr.tr("Graphics") : ""
                value: modelData
            }
        }

        InfoRow {
            label: Tr.tr("Memory")
            value: root.hw.mem ? `${(parseInt(root.hw.mem) / 1048576).toFixed(1)} GiB` : ""
        }

        InfoRow {
            label: Tr.tr("Storage")
            value: root.formattedStorage()
        }

        // Software
        SectionHeader {
            text: Tr.tr("Software")
        }

        InfoRow {
            label: Tr.trCtx("Shell", "the caelestia shell itself, not a unix shell")
            value: CUtils.version || "…"
        }

        InfoRow {
            label: Tr.tr("Command-line tool")
            value: root.cliVersion || "…"
        }

        InfoRow {
            label: "Quickshell"
            value: root.quickshellVersion || "…"
        }

        InfoRow {
            label: "Qt"
            value: CUtils.qtVersion || "…"
        }

        InfoRow {
            visible: !!root.hyprVersion
            label: "Hyprland"
            value: root.hyprVersion
        }

        // Plugins
        SectionHeader {
            text: Tr.tr("Plugins")
        }

        InfoRow {
            label: Tr.tr("Loaded plugins")
            value: root.pluginCount.toString()
        }

        RowButton {
            Layout.fillWidth: true
            icon: "content_copy"
            text: Tr.tr("Copy system information")
            subtext: Tr.tr("Copies OS, hardware and software versions for bug reports")
            onClicked: root.copySystemInfo()
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            running: true
            command: ["hyprctl", "plugin", "list"]
            stdout: StdioCollector {
                onStreamFinished: root.pluginCount = (text.match(/^Plugin /gm) ?? []).length
            }
        }
    }
}
