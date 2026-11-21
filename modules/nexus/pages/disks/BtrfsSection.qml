pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A mounted Btrfs filesystem's own tools: how its space is used, checking
// every block against its checksum (scrub), compacting half-empty chunks
// (balance) and its subvolumes. Safe while it is in use, the system's too;
// the root helper refuses deleting mounted subvolumes and snapshots.
ColumnLayout {
    id: root

    required property string mountPoint
    // The page's scroll area: dialogs open over it
    required property Item flickable

    // btrfs filesystem df: { data: [used, total], metadata: [...], system: [...] }
    property var usage: ({})
    property string scrub
    property bool scrubRunning
    property bool balanceRunning: false
    property string balanceStatus: ""
    // [{ id, path, mounted }] once asked for (listing them needs the password)
    property var subvolumes: null
    readonly property var shownSubvolumes: (subvolumes ?? []).filter(s => !s.path.startsWith(".snapshots/") && !s.path.includes(".refind-btrfs/"))
    readonly property int snapshotCount: (subvolumes ?? []).filter(s => /^\.snapshots\/\d+\/snapshot$/.test(s.path)).length

    function refresh(): void {
        dfProc.running = true;
        scrubProc.running = true;
    }

    function loadSubvolumes(): void {
        Admin.run("btrfs-subvolumes", [mountPoint], Tr.tr("List the subvolumes"), (ok, out) => {
            if (!ok)
                return;
            subvolumes = out.split("\n").filter(l => l.includes("\t") && !l.startsWith("$")).map(l => {
                const [id, path, mounted] = l.split("\t");
                return {
                    id,
                    path,
                    mounted: mounted ?? ""
                };
            });
        });
    }

    spacing: Tokens.spacing.extraSmall / 2

    Component.onCompleted: refresh()
    onMountPointChanged: refresh()

    Process {
        id: dfProc

        command: ["btrfs", "filesystem", "df", "-b", root.mountPoint]
        stdout: StdioCollector {
            onStreamFinished: {
                const u = {};
                for (const line of text.split("\n")) {
                    const m = line.match(/^(Data|Metadata|System),[^:]*:\s*total=(\d+),\s*used=(\d+)/);
                    if (m)
                        u[m[1].toLowerCase()] = [Number(m[3]), Number(m[2])];
                }
                root.usage = u;
            }
        }
    }

    Process {
        id: scrubProc

        command: ["btrfs", "scrub", "status", root.mountPoint]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scrubRunning = /Status:\s*running/.test(text);
                const errors = (text.match(/Error summary:\s*(.+)/) ?? [])[1] ?? "";
                const when = (text.match(/Scrub started:\s*(.+)/) ?? [])[1] ?? "";
                const progress = (text.match(/Bytes scrubbed:\s*(.+)/) ?? [])[1] ?? "";
                root.scrub = root.scrubRunning ? Tr.tr("Running: %1").arg(progress) : when ? Tr.tr("Last: %1 — %2").arg(when.trim()).arg(errors.trim() === "no errors found" ? Tr.tr("no errors") : errors.trim()) : Tr.tr("Never run");
            }
        }
    }

    Timer {
        running: root.scrubRunning
        interval: 3000
        repeat: true
        onTriggered: scrubProc.running = true
    }

    SectionHeader {
        text: Tr.tr("Btrfs")
    }

    InfoRow {
        icon: "data_usage"
        label: Tr.tr("Files")
        subtext: Tr.tr("Space set aside for files, and how much of it they use")
        value: root.usage.data ? Tr.tr("%1 of %2").arg(Disks.human(root.usage.data[0])).arg(Disks.human(root.usage.data[1])) : ""
    }

    InfoRow {
        icon: "account_tree"
        label: Tr.tr("Metadata")
        subtext: Tr.tr("Folders, names and small files")
        value: root.usage.metadata ? Tr.tr("%1 of %2").arg(Disks.human(root.usage.metadata[0])).arg(Disks.human(root.usage.metadata[1])) : ""
    }

    RowButton {
        readonly property string what: root.scrubRunning ? Tr.tr("Stop checking the data") : Tr.tr("Check the data (scrub)")

        icon: root.scrubRunning ? "stop_circle" : "verified"
        text: what
        subtext: root.scrub ? root.scrub : Tr.tr("Reads everything and compares it with its checksums; fixes what it can")
        disabled: Disks.busy(what)
        onClicked: Admin.run("btrfs-scrub", [root.mountPoint, root.scrubRunning ? "cancel" : "start"], what, () => scrubProc.running = true)
    }

    RowButton {
        readonly property string what: root.balanceRunning ? Tr.tr("Stop compacting free space") : Tr.tr("Compact free space (balance)")

        icon: root.balanceRunning ? "stop_circle" : "compress"
        text: what
        subtext: Disks.busy(what) ? Tr.tr("Working…") : root.balanceStatus || Tr.tr("Merges half-empty chunks so free space can be used again; runs in the background")
        disabled: Disks.busy(what)
        onClicked: Admin.run("btrfs-balance", [root.mountPoint, root.balanceRunning ? "cancel" : "start"], what, ok => {
            if (ok) {
                root.balanceRunning = !root.balanceRunning;
                root.balanceStatus = root.balanceRunning ? Tr.tr("Running in the background") : Tr.tr("Stopped");
            }
            root.refresh();
        })
    }

    RowButton {
        readonly property string what: Tr.tr("Check Btrfs maintenance status")
        readonly property bool busy: Disks.busy(what)

        icon: "sync"
        text: what
        subtext: busy ? Tr.tr("Checking…") : Tr.tr("Reads active scrub and balance progress (asks for your password)")
        disabled: busy
        onClicked: Admin.run("btrfs-status", [root.mountPoint], what, (ok, out) => {
            if (!ok)
                return;
            scrubProc.running = true;
            const running = /Balance on .* is running/i.test(out);
            root.balanceRunning = running;
            if (running) {
                const prog = out.split("\n").find(l => l.includes("chunks balanced"))?.trim() ?? "";
                root.balanceStatus = prog ? Tr.tr("Running: %1").arg(prog) : Tr.tr("Running in the background");
            } else {
                root.balanceStatus = Tr.tr("No balance running");
            }
        })
    }

    RowButton {
        visible: root.subvolumes === null
        icon: "folder_special"
        text: Tr.tr("Show the subvolumes")
        subtext: Tr.tr("Parts of the filesystem that can be mounted or snapshotted on their own")
        onClicked: root.loadSubvolumes()
    }

    Repeater {
        model: root.shownSubvolumes

        RowButton {
            id: sv

            required property var modelData

            icon: modelData.mounted ? "folder_open" : "folder"
            text: modelData.path
            subtext: modelData.mounted ? Tr.tr("Mounted at %1").arg(modelData.mounted.split(",").join(", ")) : Tr.tr("Not mounted; tap to delete")
            disabled: !!modelData.mounted || Disks.busy(deleteSvDialog.what)
            onClicked: {
                deleteSvDialog.targetSv = modelData;
                deleteSvDialog.open = true;
            }
        }
    }

    ConfirmButton {
        id: deleteSvDialog

        readonly property string what: Tr.tr("Delete the subvolume")
        property var targetSv: null

        visible: false
        rootParent: root.flickable
        icon: "delete"
        label: ""
        header: Tr.tr("Delete subvolume %1?").arg(targetSv?.path ?? "")
        message: Tr.tr("Permanently deletes the Btrfs subvolume %1 and everything inside it. This cannot be undone.").arg(targetSv?.path ?? "")
        confirmText: targetSv?.path ?? ""
        acceptLabel: Tr.trCtx("Delete", "button")
        onAccepted: if (targetSv?.path)
            Admin.run("btrfs-subvolume-delete", [root.mountPoint, targetSv.path], what, () => root.loadSubvolumes())
    }

    InfoRow {
        visible: root.snapshotCount > 0
        icon: "history"
        label: Tr.tr("Snapshots")
        subtext: Tr.tr("Managed on the Snapshots tab")
        value: String(root.snapshotCount)
    }

    DialogRowButton {
        id: newSv

        readonly property string what: Tr.tr("Make a subvolume")
        property string name

        visible: root.subvolumes !== null
        rootParent: root.flickable
        openHeight: Math.min(root.flickable.height * 0.9, 300)
        icon: "create_new_folder"
        label: Tr.tr("New subvolume")
        header: Tr.tr("New subvolume")
        acceptLabel: Tr.trCtx("Create", "button")
        acceptAllowed: /^[A-Za-z0-9@._+-][A-Za-z0-9@._+ -]{0,63}$/.test(name)
        onOpenChanged: name = ""
        content: Component {
            ColumnLayout {
                StyledTextField {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.medium
                    placeholderText: Tr.tr("Name (e.g. @games)")
                    leadingIcon: "folder"
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: newSv.name = text
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
        onAccepted: Admin.run("btrfs-subvolume-create", [root.mountPoint, name], what, () => root.loadSubvolumes())
    }
}
