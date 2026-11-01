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

// System snapshots (snapper, btrfs): the list, making one, deleting, and
// the automatic ones. Snapshots are in the boot menu (rEFInd), so the PC can
// be started from one if an update breaks it. snapper only lets users listed
// in its config (ALLOW_USERS) do this without sudo; the page offers to add
// this account once.
PageBase {
    id: root

    property string config: "root"
    property bool allowed
    property bool checked
    property bool hasSnapper
    property bool hasAssistant
    // { number, type, date, description, cleanup, userdata }
    property var snapshots: []
    property var settings: ({})
    property string newDescription

    function refresh(): void {
        listProc.running = true;
        configProc.running = true;
    }

    function snapper(args: list<string>): void {
        snapperProc.command = ["snapper", "-c", config, ...args];
        snapperProc.running = true;
    }

    title: Tr.tr("Backups")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["sh", "-c", "command -v snapper >/dev/null && echo snapper; command -v btrfs-assistant >/dev/null && echo assistant"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.hasSnapper = text.includes("snapper");
                    root.hasAssistant = text.includes("assistant");
                    if (root.hasSnapper)
                        root.refresh();
                    else
                        root.checked = true;
                }
            }
        }

        Process {
            id: listProc

            command: ["snapper", "--jsonout", "-c", root.config, "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.checked = true;
                    try {
                        const data = JSON.parse(text);
                        root.snapshots = (data[root.config] ?? []).filter(s => s.number !== 0).reverse();
                        root.allowed = true;
                    } catch (e) {
                        root.allowed = false;
                        root.snapshots = [];
                    }
                }
            }
        }

        Process {
            id: configProc

            command: ["snapper", "--jsonout", "-c", root.config, "get-config"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.settings = JSON.parse(text);
                    } catch (e) {
                        root.settings = {};
                    }
                }
            }
        }

        Process {
            id: snapperProc

            onExited: root.refresh()
        }

        // The terminal steps (sudo) take a moment: read back a few times
        Timer {
            id: recheck

            property int left

            interval: 3000
            repeat: true
            onTriggered: {
                root.refresh();
                if (--left <= 0)
                    stop();
            }
        }

        RequirementRow {
            visible: root.checked && !root.hasSnapper
            first: true
            last: true
            icon: "history"
            text: Tr.tr("Snapshots need snapper")
            subtext: Tr.tr("And a btrfs system drive. Installing it asks for your password; it then needs setting up for the drive.")
            actionText: Tr.tr("Install")
            onAction: Term.run("sudo pacman -S --needed snapper btrfs-assistant && sudo snapper -c root create-config / && echo Done.")
        }

        // Not allowed yet: one sudo step
        ConnectedRect {
            Layout.fillWidth: true
            visible: root.checked && root.hasSnapper && !root.allowed
            first: true
            last: true
            implicitHeight: allowLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: allowLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Let this account manage snapshots")
                    font: Tokens.font.body.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("snapper only shows snapshots to the users its settings allow. Allowing yours (once, with your password) lets this page list, make and delete them.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    Layout.alignment: Qt.AlignRight
                    text: Tr.tr("Allow, in a terminal")
                    type: TextButton.Filled
                    onClicked: {
                        Term.run(`sudo snapper -c ${root.config} set-config "ALLOW_USERS=$USER" SYNC_ACL=yes && echo "Done: snapshots are allowed for $USER."`);
                        recheck.left = 10;
                        recheck.restart();
                    }
                }
            }
        }

        SectionHeader {
            visible: root.allowed
            first: true
            text: Tr.tr("Make a snapshot")
        }

        TextFieldRow {
            visible: root.allowed
            first: true
            label: Tr.tr("Description")
            placeholderText: Tr.tr("e.g. Before changing drivers")
            value: root.newDescription
            onValueEdited: v => root.newDescription = v
        }

        RowButton {
            visible: root.allowed
            last: true
            icon: "add_a_photo"
            text: Tr.tr("Make a snapshot now")
            subtext: Tr.tr("Of the system drive, as it is right now")
            disabled: snapperProc.running
            onClicked: {
                root.snapper(["create", "--cleanup-algorithm", "number", "--description", root.newDescription || Tr.tr("Made in Settings")]);
                root.newDescription = "";
            }
        }

        SectionHeader {
            visible: root.allowed
            text: Tr.tr("Snapshots (%1)").arg(root.snapshots.length)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.allowed && root.snapshots.length === 0
            text: Tr.tr("No snapshots yet")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        Repeater {
            id: snapList

            model: root.allowed ? root.snapshots : []

            ConnectedRect {
                id: snap

                required property var modelData
                required property int index
                property bool confirmDelete

                Layout.fillWidth: true
                first: index === 0
                last: index === snapList.count - 1
                implicitHeight: snapLayout.implicitHeight + Tokens.padding.medium * 2

                Timer {
                    id: confirmTimer

                    interval: 4000
                    onTriggered: snap.confirmDelete = false
                }

                RowLayout {
                    id: snapLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: snap.modelData.type === "pre" || snap.modelData.type === "post" ? "update" : snap.modelData.cleanup === "timeline" ? "schedule" : "photo_camera"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: snap.modelData.description || (snap.modelData.cleanup === "timeline" ? Tr.tr("Automatic") : Tr.tr("Snapshot %1").arg(snap.modelData.number))
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `#${snap.modelData.number} · ${new Date(snap.modelData.date.replace(" ", "T")).toLocaleString(Qt.locale(), Locale.ShortFormat)}`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        text: snap.confirmDelete ? Tr.tr("Delete?") : Tr.trCtx("Delete", "button")
                        type: snap.confirmDelete ? TextButton.Filled : TextButton.Text
                        disabled: snapperProc.running
                        onClicked: {
                            if (!snap.confirmDelete) {
                                snap.confirmDelete = true;
                                confirmTimer.restart();
                                return;
                            }
                            root.snapper(["delete", String(snap.modelData.number)]);
                        }
                    }
                }
            }
        }

        SectionHeader {
            visible: root.allowed
            text: Tr.tr("Automatic snapshots")
        }

        InfoRow {
            visible: root.allowed
            first: true
            icon: "schedule"
            label: Tr.tr("Hourly snapshots")
            subtext: root.settings.TIMELINE_CREATE === "yes" ? Tr.tr("Keeps %1 hourly, %2 daily, %3 weekly").arg(root.settings.TIMELINE_LIMIT_HOURLY ?? "?").arg(root.settings.TIMELINE_LIMIT_DAILY ?? "?").arg(root.settings.TIMELINE_LIMIT_WEEKLY ?? "?") : ""
            value: root.settings.TIMELINE_CREATE === "yes" ? Tr.tr("On") : Tr.tr("Off")
        }

        RowButton {
            visible: root.allowed
            icon: root.settings.TIMELINE_CREATE === "yes" ? "timer_off" : "timer"
            text: root.settings.TIMELINE_CREATE === "yes" ? Tr.tr("Turn hourly snapshots off") : Tr.tr("Turn hourly snapshots on")
            subtext: Tr.tr("Opens a terminal")
            onClicked: {
                Term.run(`sudo snapper -c ${root.config} set-config TIMELINE_CREATE=${root.settings.TIMELINE_CREATE === "yes" ? "no" : "yes"}`);
                recheck.left = 6;
                recheck.restart();
            }
        }

        RowButton {
            visible: root.allowed && root.hasAssistant
            last: true
            icon: "open_in_new"
            text: Tr.tr("More in Btrfs Assistant")
            subtext: Tr.tr("Compare and restore files, more snapshot settings")
            onClicked: Quickshell.execDetached(["btrfs-assistant"])
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            visible: root.allowed
            text: Tr.tr("To go back to a snapshot, pick it under the system's entry in the boot menu.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }
    }
}
