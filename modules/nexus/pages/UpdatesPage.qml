pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

// System updates: pacman (checkupdates), the AUR (paru or yay) and Flatpak.
// Updating runs in a terminal, where it can ask for the password and show
// what it does.
PageBase {
    id: root

    // [{ name, from, to }]
    property var repo: []
    property var aur: []
    property var flatpaks: []
    property int pending
    property date checkedAt
    property string aurHelper
    property bool hasFlatpak

    readonly property bool checking: pending > 0
    readonly property int total: repo.length + aur.length + flatpaks.length

    function check(): void {
        pending = 1 + (aurHelper ? 1 : 0) + (hasFlatpak ? 1 : 0);
        repoProc.running = true;
        if (aurHelper)
            aurProc.running = true;
        if (hasFlatpak)
            flatpakProc.running = true;
    }

    function done(): void {
        if (--pending <= 0)
            checkedAt = new Date();
    }

    // "name 1.0-1 -> 1.1-1" lines
    function parsePkgs(text: string): var {
        return text.split("\n").map(l => l.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)).filter(m => m).map(m => ({
                    name: m[1],
                    from: m[2],
                    to: m[3]
                }));
    }

    function updateAll(): void {
        const steps = [`${aurHelper || "sudo pacman"} -Syu`];
        if (hasFlatpak)
            steps.push("flatpak update");
        Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "-e", "sh", "-c", `${steps.join(" && ")}; echo; read -p 'Done. Press Enter to close' _`]);
    }

    title: Tr.tr("Updates")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("System updates")
        }

        InfoRow {
            first: true
            icon: root.checking ? "sync" : root.total > 0 ? "system_update" : "check_circle"
            label: root.checking ? Tr.tr("Checking for updates…") : root.total > 0 ? Tr.tr("%1 updates available").arg(root.total) : Tr.tr("Up to date")
            subtext: root.checkedAt.getTime() > 0 ? Tr.tr("Last checked at %1").arg(Qt.formatTime(root.checkedAt, "HH:mm")) : ""
        }

        RowButton {
            disabled: root.checking
            icon: "refresh"
            text: Tr.tr("Check again")
            onClicked: root.check()
        }

        RowButton {
            last: true
            disabled: root.checking || root.total === 0
            icon: "download"
            text: Tr.tr("Update everything")
            subtext: Tr.tr("Opens a terminal: it asks for your password and shows the progress")
            onClicked: root.updateAll()
        }

        PkgSection {
            title: Tr.tr("Packages")
            pkgs: root.repo
        }

        PkgSection {
            title: Tr.tr("AUR")
            pkgs: root.aur
        }

        PkgSection {
            title: Tr.tr("Flatpak")
            pkgs: root.flatpaks
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            running: true
            command: ["sh", "-c", "command -v paru || command -v yay; command -v flatpak >/dev/null && echo FLATPAK"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n").filter(s => s);
                    root.hasFlatpak = lines.includes("FLATPAK");
                    root.aurHelper = lines.find(l => l.startsWith("/"))?.split("/").pop() ?? "";
                    root.check();
                }
            }
        }

        Process {
            id: repoProc

            command: ["checkupdates"]
            // qmllint disable incompatible-type
            environment: ({
                    // qmllint enable incompatible-type
                    LANG: "C.UTF-8",
                    LC_ALL: "C.UTF-8"
                })
            stdout: StdioCollector {
                onStreamFinished: root.repo = root.parsePkgs(text)
            }
            onExited: root.done()
        }

        Process {
            id: aurProc

            command: [root.aurHelper || "true", "-Qua"]
            // qmllint disable incompatible-type
            environment: ({
                    // qmllint enable incompatible-type
                    LANG: "C.UTF-8",
                    LC_ALL: "C.UTF-8"
                })
            stdout: StdioCollector {
                onStreamFinished: root.aur = root.parsePkgs(text)
            }
            onExited: root.done()
        }

        Process {
            id: flatpakProc

            command: ["flatpak", "remote-ls", "--updates", "--columns=application,version"]
            stdout: StdioCollector {
                onStreamFinished: root.flatpaks = text.split("\n").filter(s => s.trim()).map(l => {
                        const [name, version] = l.split("\t");
                        return {
                            name,
                            from: "",
                            to: version ?? ""
                        };
                    })
            }
            onExited: root.done()
        }
    }

    component PkgSection: ColumnLayout {
        id: section

        required property string title
        required property var pkgs

        Layout.fillWidth: true
        visible: pkgs.length > 0
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: `${section.title} (${section.pkgs.length})`
        }

        Repeater {
            // A long list stays readable: the first 50
            model: section.pkgs.slice(0, 50)

            InfoRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Math.min(section.pkgs.length, 50) - 1
                label: modelData.name
                value: modelData.from ? `${modelData.from} → ${modelData.to}` : modelData.to
            }
        }
    }
}
