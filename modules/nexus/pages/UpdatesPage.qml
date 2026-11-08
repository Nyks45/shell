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
// Updating runs here, one source after the other, showing its progress; the
// shell's password prompt asks (repository packages through the settings'
// helper, the AUR helper's install step through pkexec, Flatpak by itself).
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

    // "repo", "aur", "flatpak" while updating
    property string updateStep
    readonly property string updateWhat: Tr.tr("Install the updates")
    readonly property bool updating: Admin.jobs.some(j => j.what === updateWhat) || updateStep !== ""
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
        const flatpak = () => {
            if (!hasFlatpak || flatpaks.length === 0) {
                updateStep = "";
                check();
                return;
            }
            updateStep = "flatpak";
            Admin.exec(["flatpak", "update", "--noninteractive", "-y"], updateWhat, () => {
                updateStep = "";
                check();
            });
        };
        const aurStep = () => {
            if (!aurHelper || aur.length === 0)
                return flatpak();
            updateStep = "aur";
            Admin.exec([aurHelper, "-Sua", "--noconfirm", ...(aurHelper === "paru" ? ["--skipreview"] : []), "--sudo", "pkexec"], updateWhat, ok => ok ? flatpak() : (updateStep = "", check()));
        };
        if (repo.length === 0)
            return aurStep();
        updateStep = "repo";
        Admin.run("upgrade", [], updateWhat, ok => ok ? aurStep() : (updateStep = "", check()));
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
            disabled: root.checking || root.total === 0 || root.updating
            icon: "download"
            text: Tr.tr("Update everything")
            subtext: {
                if (!root.updating)
                    return Tr.tr("Asks for your password, then shows the progress here");
                const last = (Admin.outputOf(root.updateWhat).trim().split("\n").pop() ?? "").replace(/^\$ /, "").slice(0, 110);
                const step = root.updateStep === "repo" ? Tr.tr("System packages") : root.updateStep === "aur" ? Tr.tr("AUR packages") : Tr.tr("Flatpak apps");
                return last ? `${step}: ${last}` : step;
            }
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

                label: modelData.name
                value: modelData.from ? `${modelData.from} → ${modelData.to}` : modelData.to
            }
        }
    }
}
