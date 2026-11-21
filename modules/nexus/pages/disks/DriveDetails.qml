pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// A drive's contents, unfolded under its card on Disks & drives: its layout
// (click a part), its partitions and free space (a partition opens its page;
// free space can get a new partition), its health and what can be done to
// the whole drive.
ColumnLayout {
    id: root

    required property var drive
    required property NexusState nState
    // The page's scroll area: dialogs open over it
    required property Item flickable
    // The drive's segments in disk order (PartitionMap's, for the list)
    readonly property var segments: map.segments
    readonly property string systemRoles: {
        const parts = [...(root.drive?.partitions ?? []), ...(root.drive?.whole ? [root.drive.whole] : [])];
        const roles = [...new Set(parts.map(p => p.system).filter(Boolean))];
        return roles.join(", ");
    }
    property string selected

    function openPartition(id: string): void {
        nState.selectedDrive = drive.id;
        nState.selectedPartition = id;
        nState.openSubPage(1);
    }

    spacing: Tokens.spacing.extraSmall / 2

    PartitionMap {
        id: map

        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        barHeight: Tokens.padding.large * 3.2
        showLegend: true
        drive: root.drive
        interactive: true
        selected: root.selected
        onClicked: seg => {
            if (seg.kind === "part")
                root.openPartition(seg.id);
            else
                root.selected = seg.id;
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        visible: !!root.systemRoles
        text: Tr.tr("This drive holds the running system (%1): system partitions are locked while running. Other partitions and free space can still be changed.").arg(root.systemRoles)
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.WordWrap
    }

    // ---- Partitions and free space -----------------------------------
    SectionHeader {
        visible: !!root.drive
        text: root.drive?.whole ? Tr.tr("Contents") : Tr.tr("Partitions")
    }

    Repeater {
        id: segList

        model: root.drive ? root.segments : []

        Loader {
            id: segRow

            required property var modelData
            required property int index

            Layout.fillWidth: true
            sourceComponent: modelData.kind === "part" ? partRow : freeRow

            Component {
                id: partRow

                ConnectedRect {
                    id: prow

                    readonly property var p: segRow.modelData.part
                    readonly property var fs: p.crypto?.inner ?? p.fs
                    readonly property var job: Disks.jobFor(p.id)
                    readonly property real usedRatio: fs?.size > 0 && fs.used >= 0 ? Math.min(1, fs.used / fs.size) : -1

                    Layout.fillWidth: true
                    implicitHeight: prowCol.implicitHeight + Tokens.padding.medium * 2

                    StateLayer {
                        onClicked: root.openPartition(prow.p.id)
                    }

                    ColumnLayout {
                        id: prowCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.medium

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: Disks.fsColor(prow.p)
                            }

                            MaterialIcon {
                                text: prow.p.crypto ? (prow.p.crypto.unlocked ? "lock_open" : "lock") : prow.p.system ? "shield" : (prow.fs.mounts.length > 0 || (prow.fs.sharedMounts?.length ?? 0) > 0) ? "folder_open" : "storage"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Disks.partName(prow.p, root.drive)
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: prow.job ? Tr.tr("%1… %2%").arg(prow.job.operation).arg(Math.round(prow.job.progress * 100)) : [Disks.fsName(prow.p.fs.type), Disks.human(prow.p.size), prow.fs.mounts[0] ?? prow.fs.sharedMounts?.[0] ?? "", prow.usedRatio >= 0 ? Tr.tr("%1 free").arg(Disks.human(prow.fs.size - prow.fs.used)) : "", prow.p.system ? Tr.tr("system lock") : ""].filter(x => x).join(" · ")
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MaterialIcon {
                                text: "chevron_right"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                            }
                        }

                        StyledProgressBar {
                            Layout.fillWidth: true
                            visible: prow.usedRatio >= 0
                            value: prow.usedRatio >= 0 ? prow.usedRatio : 0
                        }
                    }
                }
            }

            Component {
                id: freeRow

                DialogRowButton {
                    id: create

                    readonly property var gap: segRow.modelData
                    readonly property string what: Tr.tr("Create a partition")
                    readonly property real mib: 1048576
                    readonly property real maxMiB: Math.max(1, Math.floor(gap.size / mib))
                    property real sizeMiB: Math.floor(gap.size / mib)
                    property bool useLargeUnit: true

                    rootParent: root.flickable
                    openWidth: Math.min(root.flickable.width * 0.9, 520)
                    openHeight: Math.min(root.flickable.height * 0.95, 650)
                    icon: "add"
                    label: Tr.tr("Free space · %1 · create a partition").arg(Disks.human(gap.size))
                    header: Tr.tr("New partition")
                    acceptLabel: Tr.trCtx("Create", "button")
                    acceptAllowed: spec.valid && sizeMiB >= 1 && !Disks.busy(what)

                    FormatSpec {
                        id: spec
                    }

                    onOpenChanged: if (open) {
                        spec.reset("ext4");
                        useLargeUnit = maxMiB >= 1024;
                        sizeMiB = maxMiB;
                    }

                    content: Component {
                        ColumnLayout {
                            spacing: Tokens.spacing.small

                            Connections {
                                target: create
                                function onOpenChanged(): void {
                                    if (create.open)
                                        createSizeInput.text = Disks.formatUnitBytes(create.sizeMiB * create.mib, create.useLargeUnit);
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.topMargin: Tokens.spacing.medium
                                text: Tr.tr("Size: %1 of %2").arg(Disks.human(create.sizeMiB * create.mib)).arg(Disks.human(create.gap.size))
                                font: Tokens.font.body.small
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                StyledTextField {
                                    id: createSizeInput

                                    Layout.preferredWidth: 120
                                    verticalPadding: Tokens.padding.small
                                    floatingPlaceholder: false
                                    text: Disks.formatUnitBytes(create.sizeMiB * create.mib, create.useLargeUnit)
                                    validator: DoubleValidator {
                                        bottom: 0.01
                                        decimals: 2
                                    }
                                    onEditingFinished: {
                                        const v = parseFloat(text);
                                        if (isFinite(v) && v > 0)
                                            create.sizeMiB = Math.max(1, Math.min(create.maxMiB, Math.round(v * Disks.unitDivisor(create.useLargeUnit) / create.mib)));
                                        text = Disks.formatUnitBytes(create.sizeMiB * create.mib, create.useLargeUnit);
                                    }
                                }

                                TextButton {
                                    text: Disks.unitLabel(create.useLargeUnit)
                                    type: TextButton.Tonal
                                    onClicked: {
                                        create.useLargeUnit = !create.useLargeUnit;
                                        createSizeInput.text = Disks.formatUnitBytes(create.sizeMiB * create.mib, create.useLargeUnit);
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            // StyledSlider works in 0..1
                            StyledSlider {
                                Layout.fillWidth: true
                                implicitHeight: Tokens.padding.large * 2
                                value: create.maxMiB > 1 ? (create.sizeMiB - 1) / (create.maxMiB - 1) : 1
                                onInteraction: v => {
                                    create.sizeMiB = Math.max(1, Math.round(1 + v * (create.maxMiB - 1)));
                                    createSizeInput.text = Disks.formatUnitBytes(create.sizeMiB * create.mib, create.useLargeUnit);
                                }
                            }

                            FormatOptions {
                                Layout.fillWidth: true
                                spec: spec
                            }

                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }

                    onAccepted: {
                        const size = Math.min(gap.size, sizeMiB * mib);
                        Disks.run("create", [root.drive.block, String(gap.offset), String(size), spec.fstype, spec.label || "", "", ...spec.flags], what, ok => {
                            if (ok)
                                root.selected = "";
                        }, spec.encrypting ? spec.passphrase : "");
                        spec.passphrase = "";
                        spec.repeat = "";
                    }
                }
            }
        }
    }

    RowButton {
        visible: !!root.drive && !root.drive.table && !root.drive.whole
        icon: "info"
        text: Tr.tr("No partition table")
        subtext: Tr.tr("Make one below (under Drive) to put partitions on it")
        disabled: true
    }

    // ---- Health --------------------------------------------------------
    SectionHeader {
        visible: !!root.drive?.health
        text: Tr.tr("Health")
    }

    NavRow {
        readonly property var h: root.drive?.health

        visible: !!h
        icon: h?.status === "good" ? "health_and_safety" : "warning"
        text: h?.status === "failing" ? Tr.tr("Failing: back up its data now") : h?.status === "warning" ? Tr.tr("Showing problems") : Tr.tr("Healthy")
        subtext: h ? [h.temperature !== null && h.temperature !== undefined ? `${h.temperature} °C` : "", Tr.tr("on for %1 hours").arg(h.powerOnHours), h.selftestRemaining > 0 ? Tr.tr("self-test %1% left").arg(h.selftestRemaining) : ""].filter(x => x).join(" · ") : ""
        onClicked: {
            root.nState.selectedDrive = root.drive.id;
            root.nState.openSubPage(2);
        }
    }

    // ---- The whole drive ------------------------------------------------
    SectionHeader {
        visible: !!root.drive && (!root.drive.system || root.drive.bus === "loop")
        text: Tr.tr("Drive")
    }

    ConfirmButton {
        id: tableBtn

        readonly property string what: Tr.tr("Make a new partition table")

        visible: !!root.drive && !root.drive.system
        rootParent: root.flickable
        icon: "table_rows"
        label: Tr.tr("New partition table (erases the whole drive)")
        header: Tr.tr("Erase %1?").arg(root.drive?.model || root.drive?.device || "")
        message: Tr.tr("Everything on %1 (%2) is deleted: all partitions and their files. GPT suits every modern PC; MBR only very old ones.").arg(root.drive?.device ?? "").arg(Disks.human(root.drive?.size ?? 0))
        confirmText: root.drive?.device.replace("/dev/", "") ?? ""
        acceptLabel: Tr.trCtx("Erase", "button")
        onAccepted: Disks.run("table", [root.drive.block, "gpt"], what)
    }

    RowButton {
        visible: !!root.drive && (root.drive.canPowerOff || root.drive.ejectable) && !root.drive.system
        icon: "eject"
        text: root.drive?.canPowerOff ? Tr.tr("Power off (safe to unplug)") : Tr.tr("Eject")
        subtext: Tr.tr("Unmount its partitions first")
        onClicked: Disks.run(root.drive.canPowerOff ? "power-off" : "eject", [root.drive.id], Tr.tr("Power off the drive"))
    }

    RowButton {
        visible: root.drive?.bus === "loop"
        icon: "close"
        text: Tr.tr("Detach this disk image")
        subtext: root.drive?.backingFile ?? ""
        onClicked: Disks.run("loop-delete", [root.drive.block], Tr.tr("Detach the disk image"))
    }
}
