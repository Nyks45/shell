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
    // [{ kind: "+"|"-"|"c", path }]
    property var changes: []
    property bool loading: true
    property string filter
    readonly property var shown: {
        const f = filter.toLowerCase();
        const list = f ? changes.filter(c => c.path.toLowerCase().includes(f)) : changes;
        return list.slice(0, 300);
    }
    property string restored

    title: Tr.tr("Snapshot %1").arg(number)
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Non-visual (the page takes one item: it lives in the column)
        Process {
            id: statusProc

            running: root.number > 0
            command: ["snapper", "-c", root.config, "status", `${root.number}..0`]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.changes = text.split("\n").map(l => l.match(/^([+\-ct])[.\w]{5,}\s+(\/.*)$/)).filter(m => m).map(m => ({
                                kind: m[1],
                                path: m[2]
                            }));
                    root.loading = false;
                }
            }
            onExited: code => {
                if (code !== 0)
                    root.loading = false;
            }
        }

        SectionHeader {
            text: Tr.tr("This snapshot")
        }

        RowButton {
            icon: "folder_open"
            text: Tr.tr("Look through its files")
            subtext: Tr.tr("Opens the system as it was then (read-only)")
            onClicked: Quickshell.execDetached(["xdg-open", `/.snapshots/${root.number}/snapshot`])
        }

        SectionHeader {
            text: root.loading ? Tr.tr("What changed since then…") : Tr.tr("What changed since then (%1)").arg(root.changes.length)
        }

        StyledTextField {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.changes.length > 8
            placeholderText: Tr.tr("Find a file or folder")
            leadingIcon: "search"
            onTextChanged: root.filter = text
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
                id: change

                required property var modelData
                readonly property string what: Tr.tr("Restore from the snapshot")
                property bool confirm

                icon: modelData.kind === "+" ? "add_circle" : modelData.kind === "-" ? "remove_circle" : "change_circle"
                text: modelData.path
                subtext: confirm ? (modelData.kind === "+" ? Tr.tr("Click again: it didn't exist then, so it is removed") : Tr.tr("Click again to put it back as it was")) : modelData.kind === "+" ? Tr.tr("Added since") : modelData.kind === "-" ? Tr.tr("Deleted since") : Tr.tr("Changed since")
                disabled: Admin.jobs.some(j => j.what === what)
                onClicked: {
                    if (!confirm) {
                        confirm = true;
                        confirmReset.restart();
                        return;
                    }
                    confirm = false;
                    Admin.run("snapper-restore", [root.config, String(root.number), modelData.path], what, ok => {
                        if (ok) {
                            root.restored = Tr.tr("Restored %1").arg(modelData.path);
                            statusProc.running = true;
                        }
                    });
                }

                Timer {
                    id: confirmReset

                    interval: 4000
                    onTriggered: change.confirm = false
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.changes.length > root.shown.length
            text: Tr.tr("Showing %1 of %2: find a file to narrow it down.").arg(root.shown.length).arg(root.filter ? root.changes.filter(c => c.path.toLowerCase().includes(root.filter.toLowerCase())).length : root.changes.length)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
