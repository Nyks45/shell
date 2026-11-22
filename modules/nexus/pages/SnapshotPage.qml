pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// One system snapshot: what changed since it (snapper status), putting a file
// or folder back as it was then (the root helper's snapper-restore), and its
// files to look through.
PageBase {
    id: root

    readonly property int number: nState.selectedSnapshot
    readonly property string config: nState.selectedSnapperConfig || "root"
    property string subvolume: "/"
    // [{ kind: "+"|"-"|"c"|"t", path, lower }]
    property var changes: []
    property bool loading: true
    property string pendingFilter
    property string filter
    property int limit: 50
    readonly property var matching: {
        const f = filter.toLowerCase();
        return f ? changes.filter(c => c.lower.includes(f)) : changes;
    }
    readonly property var shown: matching.slice(0, limit)
    property string restored

    title: nState.selectedSnapshotLabel || Tr.tr("Snapshot #%1").arg(number)
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: configProc

            running: true
            command: ["snapper", "--jsonout", "-c", root.config, "get-config"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const cfg = JSON.parse(text);
                        if (cfg.SUBVOLUME)
                            root.subvolume = cfg.SUBVOLUME;
                    } catch (e) {}
                }
            }
        }

        // Single-pass parser handles tens of thousands of changed paths quickly
        Process {
            id: statusProc

            running: root.number > 0
            command: ["snapper", "-c", root.config, "status", `${root.number}..0`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = [];
                    const lines = text.split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i];
                        if (line.length < 8)
                            continue;
                        const sp = line.indexOf(" ");
                        if (sp <= 0)
                            continue;
                        const kind = line[0];
                        if (kind !== "+" && kind !== "-" && kind !== "c" && kind !== "t")
                            continue;
                        let j = sp;
                        while (j < line.length && line[j] === " ")
                            j++;
                        if (j >= line.length || line[j] !== "/")
                            continue;
                        const p = line.slice(j);
                        out.push({
                            kind,
                            path: p,
                            lower: p.toLowerCase()
                        });
                    }
                    root.changes = out;
                    root.loading = false;
                }
            }
            onExited: code => {
                if (code !== 0)
                    root.loading = false;
            }
        }

        Timer {
            id: filterTimer

            interval: 250
            onTriggered: {
                root.limit = 50;
                root.filter = root.pendingFilter;
            }
        }

        SectionHeader {
            text: Tr.tr("This snapshot")
        }

        RowButton {
            icon: "folder_open"
            text: Tr.tr("Look through its files")
            subtext: Tr.tr("Opens the snapshot as it was then (read-only)")
            onClicked: {
                const base = root.subvolume === "/" ? "" : root.subvolume.replace(/\/$/, "");
                Quickshell.execDetached(["xdg-open", `${base}/.snapshots/${root.number}/snapshot`]);
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Roll back system snapshot")

            visible: root.config === "root" && root.number > 0
            icon: "restore"
            text: Tr.tr("Roll back system to this snapshot…")
            subtext: Tr.tr("Sets snapshot #%1 as the active system root for the next restart").arg(root.number)
            disabled: Admin.jobs.some(j => j.what === what)
            onClicked: rollbackConfirm.ask({
                header: Tr.tr("Roll back to snapshot #%1?").arg(root.number),
                body: Tr.tr("Creates a writable snapshot from #%1 as the next boot root and updates rEFInd. Files changed in / since that snapshot will revert after you restart (/home is separate).").arg(root.number),
                confirmLabel: Tr.tr("Roll back"),
                icon: "restore",
                onConfirm: () => Admin.run("snapper-rollback", [String(root.number)], what, ok => {
                    if (ok)
                        Toaster.toast(Tr.tr("Rollback scheduled"), Tr.tr("Restart to boot into snapshot #%1").arg(root.number), "restore");
                })
            })
        }

        ConfirmDialog {
            id: rollbackConfirm

            hostFlickable: root.flickable
        }

        SectionHeader {
            text: root.loading ? Tr.tr("What changed since then…") : Tr.tr("What changed since then (%1)").arg(root.changes.length)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.loading
            spacing: Tokens.spacing.small

            LoadingIndicator {
                implicitSize: Tokens.font.body.small.pointSize * 1.5
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Comparing snapshot #%1 with current files… (can take a few seconds)").arg(root.number)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }
        }

        StyledTextField {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.changes.length > 8
            placeholderText: Tr.tr("Find a file or folder")
            leadingIcon: "search"
            onTextChanged: {
                root.pendingFilter = text;
                filterTimer.restart();
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.restored !== ""
            text: root.restored
            color: Colours.palette.m3primary
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !root.loading && root.changes.length === 0
            text: Tr.tr("Nothing changed (or this account may not see this snapshot).")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.shown

            RowButton {
                required property var modelData
                readonly property string what: Tr.tr("Restore from the snapshot")

                icon: modelData.kind === "+" ? "add_circle" : modelData.kind === "-" ? "remove_circle" : "change_circle"
                text: modelData.path
                subtext: modelData.kind === "+" ? Tr.tr("Added since · tap to delete") : modelData.kind === "-" ? Tr.tr("Deleted since · tap to restore") : Tr.tr("Changed since · tap to restore")
                disabled: Admin.jobs.some(j => j.what === what)
                onClicked: {
                    restoreDialog.pendingChange = modelData;
                    restoreDialog.open = true;
                }
            }
        }

        RowButton {
            visible: root.matching.length > root.shown.length
            icon: "expand_more"
            text: Tr.tr("Show %1 more").arg(Math.min(50, root.matching.length - root.shown.length))
            subtext: Tr.tr("Showing %1 of %2 matching paths").arg(root.shown.length).arg(root.matching.length)
            onClicked: root.limit += 50
        }

        DialogRowButton {
            id: restoreDialog

            readonly property string what: Tr.tr("Restore from the snapshot")
            property var pendingChange: null
            readonly property bool isAdd: pendingChange?.kind === "+"
            readonly property bool isDel: pendingChange?.kind === "-"

            visible: false
            rootParent: root.flickable
            openWidth: Math.min(root.flickable.width * 0.85, 480)
            openHeight: Math.min(root.flickable.height * 0.9, 340)
            icon: isAdd ? "delete_forever" : "restore"
            label: ""
            header: isAdd ? Tr.tr("Delete this file permanently?") : isDel ? Tr.tr("Restore deleted file?") : Tr.tr("Restore earlier version?")
            acceptLabel: isAdd ? Tr.tr("Delete permanently") : Tr.tr("Restore")
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: restoreDialog.isAdd
                            ? Tr.tr("%1 did not exist in snapshot #%2. Rolling this change back will permanently delete it from your system.").arg(restoreDialog.pendingChange?.path ?? "").arg(root.number)
                            : restoreDialog.isDel
                            ? Tr.tr("Brings back %1 from snapshot #%2. Note: if a deleted folder had files inside, restore needed files inside it individually.").arg(restoreDialog.pendingChange?.path ?? "").arg(root.number)
                            : Tr.tr("Replaces %1 with its version from snapshot #%2. Any changes made to it since then will be lost.").arg(restoreDialog.pendingChange?.path ?? "").arg(root.number)
                        color: restoreDialog.isAdd ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                const c = pendingChange;
                if (!c)
                    return;
                Admin.run("snapper-restore", [root.config, String(root.number), c.path], what, ok => {
                    if (ok) {
                        root.restored = c.kind === "+" ? Tr.tr("Deleted %1").arg(c.path) : Tr.tr("Restored %1").arg(c.path);
                        root.loading = true;
                        statusProc.running = true;
                    }
                });
            }
        }
    }
}
