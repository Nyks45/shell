pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// One partition (or a drive's whole-disk filesystem): what is on it and
// everything a partition manager does with it. The system's own partitions
// (/, /boot, /home...) show what they are but can't be erased or reshaped.
PageBase {
    id: root

    readonly property var realPart: Disks.block(nState.selectedPartition)
    readonly property var p: Disks.previewBlock(nState.selectedPartition)
    readonly property var drive: Disks.previewDrive(Disks.driveOf(nState.selectedPartition))
    readonly property var drivePending: drive ? Disks.pendingForDrive(drive.id) : []
    readonly property bool isPartition: !!p && p.number !== undefined
    readonly property bool gpt: drive?.table === "gpt"
    // An unlocked encrypted partition: its filesystem is the cleartext device's
    readonly property var fs: p ? (p.crypto?.inner ?? p.fs) : null
    readonly property string fsTarget: p ? (p.crypto?.cleartext || p.id) : ""
    // Mounted itself, or through another device of the same filesystem (a
    // multi-device Btrfs: mounted from its first device)
    readonly property bool mounted: (fs?.mounts.length ?? 0) > 0 || (fs?.sharedMounts?.length ?? 0) > 0
    readonly property var mountList: fs ? [...fs.mounts, ...(fs.sharedMounts ?? [])] : []
    readonly property bool locked: !!p?.crypto && !p.crypto.unlocked
    readonly property bool hasFs: !!fs?.isFilesystem
    readonly property bool linuxFs: ["ext4", "ext3", "ext2", "btrfs", "xfs", "f2fs"].includes(fs?.type ?? "")
    readonly property var job: p ? (Disks.jobFor(p.id) ?? Disks.jobFor(fsTarget)) : null
    readonly property var freeBeforeGap: {
        if (!isPartition || !drive)
            return null;
        return drive.free.find(f => f.offset + f.size <= p.offset && f.offset + f.size > p.offset - 1048576) ?? null;
    }
    readonly property var freeAfterGap: {
        if (!isPartition || !drive)
            return null;
        const end = p.offset + p.size;
        return drive.free.find(f => f.offset >= end && f.offset < end + 1048576) ?? null;
    }
    readonly property real freeBeforeSize: freeBeforeGap ? freeBeforeGap.size : 0
    // Free space right after it (what it can grow into)
    readonly property real growRoom: freeAfterGap ? freeAfterGap.offset + freeAfterGap.size - (p.offset + p.size) : 0
    readonly property real spanStart: freeBeforeGap ? freeBeforeGap.offset : (p?.offset ?? 0)
    readonly property int spanTotalMiB: p ? Math.max(1, Math.floor((freeBeforeSize + p.size + growRoom) / 1048576)) : 1
    readonly property int curBeforeMiB: p ? Math.max(0, Math.floor((p.offset - spanStart) / 1048576)) : 0
    readonly property int curSizeMiB: p ? Math.max(1, Math.floor(p.size / 1048576)) : 1
    readonly property int origBeforeMiB: (realPart && p) ? Math.max(0, Math.min(spanTotalMiB - 1, Math.floor((realPart.offset - spanStart) / 1048576))) : curBeforeMiB
    readonly property int origSizeMiB: realPart ? Math.max(1, Math.min(spanTotalMiB, Math.floor(realPart.size / 1048576))) : curSizeMiB
    readonly property string pname: p ? Disks.partName(p, drive) : ""
    readonly property string lockText: Disks.lockReason(p)
    property bool showAdvanced: false

    function toggleMountOpt(opt: string, on: bool): void {
        const entry = root.fs?.fstab?.[0];
        if (!entry)
            return;
        let parts = (entry.opts || "").split(",").map(s => s.trim()).filter(Boolean);
        parts = parts.filter(s => s !== opt);
        if (on) {
            if (opt === "ro")
                parts = parts.filter(s => s !== "rw");
            parts.push(opt);
        }
        if (parts.length === 0)
            parts = ["defaults"];
        Disks.run("fstab", [root.p.id, entry.dir, parts.join(",")], Tr.tr("Change mount options"));
    }

    function hasMountOpt(opt: string): bool {
        const entry = root.fs?.fstab?.[0];
        if (!entry || !entry.opts)
            return false;
        return entry.opts.split(",").map(s => s.trim()).includes(opt);
    }
    // Where it can start (moving it, same size): from the free space right
    // before it to the end of the free space right after it, 1 MiB steps
    readonly property real moveFrom: {
        if (!isPartition || !drive)
            return 0;
        const gap = drive.free.find(f => f.offset + f.size <= p.offset && f.offset + f.size > p.offset - 1048576);
        return gap ? gap.offset : p.offset;
    }
    readonly property real moveTo: isPartition ? p.offset + Math.floor(growRoom / 1048576) * 1048576 : 0

    title: p ? pname : Tr.tr("Partition")
    isSubPage: true

    Component.onCompleted: Disks.open()
    Component.onDestruction: Disks.close()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            visible: !root.p
            Layout.fillWidth: true
            text: Disks.loaded ? Tr.tr("This partition isn't there any more.") : Tr.tr("Reading the drive…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }

        // ---- What it is ----------------------------------------------------
        ConnectedRect {
            visible: !!root.p
            Layout.fillWidth: true
            implicitHeight: info.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: info

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.p ? [Disks.fsName(root.p.fs.type), root.p.crypto ? (root.locked ? Tr.tr("locked") : Disks.fsName(root.fs?.type ?? "")) : "", Disks.human(root.p.size)].filter(x => x).join(" · ") : ""
                    font: Tokens.font.body.medium
                    wrapMode: Text.WordWrap
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    visible: (root.fs?.size ?? 0) > 0 && (root.fs?.used ?? -1) >= 0
                    value: visible ? root.fs.used / root.fs.size : 0
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: (root.fs?.used ?? -1) >= 0 && (root.fs?.size ?? 0) > 0
                    text: Tr.tr("%1 used, %2 free").arg(Disks.human(root.fs?.used ?? 0)).arg(Disks.human((root.fs?.size ?? 0) - (root.fs?.used ?? 0)))
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: [root.mounted ? Tr.tr("Mounted at %1").arg(root.mountList.join(", ")) : Tr.tr("Not mounted"), root.p?.typeName || ""].filter(x => x).join(" · ")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: (root.fs?.members?.length ?? 0) > 0
                    text: Tr.tr("One filesystem together with %1: they are used as one, so none of them can be erased on its own.").arg(root.fs?.members?.join(", ") ?? "")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.job
                    text: root.job ? Tr.tr("Working: %1… %2%").arg(root.job.operation).arg(Math.round(root.job.progress * 100)) : ""
                    color: Colours.palette.m3primary
                    font: Tokens.font.body.small
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.lockText
                    text: root.lockText
                    color: root.p?.system ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !root.p?.system && ["EFI system", "Microsoft reserved", "Windows recovery"].includes(root.p?.typeName ?? "")
                    text: Tr.tr("Other systems (Windows) need this to start: don't erase it unless you removed them.")
                    color: Colours.palette.m3error
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        ConnectedRect {
            visible: !!root.p && root.drivePending.length > 0
            Layout.fillWidth: true
            implicitHeight: partPendCol.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: partPendCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "pending_actions"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Disks.applyingPending ? (Disks.applyProgressText || Tr.tr("Applying changes…")) : (root.drivePending.length === 1 ? Tr.tr("1 pending change on %1").arg(root.drive?.device ?? "") : Tr.tr("%1 pending changes on %2").arg(root.drivePending.length).arg(root.drive?.device ?? ""))
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    TextButton {
                        text: Tr.tr("Undo")
                        type: TextButton.Tonal
                        disabled: Disks.applyingPending
                        onClicked: Disks.undoPending(root.drive.id)
                    }

                    TextButton {
                        text: Tr.tr("Apply…")
                        type: TextButton.Filled
                        disabled: Disks.applyingPending || Disks.busy("")
                        onClicked: applyConfirm.ask({
                            header: Tr.tr("Apply pending changes?"),
                            body: root.drivePending.map((op, i) => `${i + 1}. ${op.summary}`).join("\n"),
                            warning: Tr.tr("Partition changes modify the disk layout on %1. Back up important files first and do not turn off the PC while applying.").arg(root.drive?.device ?? ""),
                            confirmLabel: Tr.trCtx("Apply", "button"),
                            icon: "warning",
                            onConfirm: () => Disks.applyPending(root.drive.id, null)
                        })
                    }
                }
            }
        }

        // ---- Use it ----------------------------------------------------------
        SectionHeader {
            visible: !!root.p
            text: Tr.tr("Use")
        }

        // Locked: open it with its passphrase
        DialogRowButton {
            id: unlock

            readonly property string what: Tr.tr("Unlock the encrypted partition")
            property string pass

            visible: root.locked
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 300)
            icon: "lock_open"
            label: Tr.tr("Unlock")
            header: Tr.tr("Unlock %1").arg(root.pname)
            acceptLabel: Tr.trCtx("Unlock", "button")
            acceptAllowed: pass.length > 0
            onOpenChanged: pass = ""
            content: Component {
                ColumnLayout {
                    StyledTextField {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Passphrase")
                        leadingIcon: "key"
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: unlock.pass = text
                        onAccepted: if (unlock.acceptAllowed) {
                            unlock.accepted();
                            unlock.open = false;
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                Disks.run("unlock", [root.p.id], what, null, pass);
                pass = "";
            }
        }

        RowButton {
            visible: root.hasFs && !root.locked && root.fs?.type !== "swap" && !((root.fs?.sharedMounts?.length ?? 0) > 0)
            icon: root.mounted ? "eject" : "folder_open"
            text: root.mounted ? Tr.tr("Unmount") : Tr.tr("Mount")
            subtext: root.mounted ? (root.p.system ? Tr.tr("In use by the system") : Tr.tr("Safe to remove or change afterwards")) : Tr.tr("Makes its files available")
            disabled: !!root.p?.system || Disks.busy(text)
            onClicked: Disks.run(root.mounted ? "unmount" : "mount", [root.fsTarget], root.mounted ? Tr.tr("Unmount") : Tr.tr("Mount"))
        }

        RowButton {
            visible: root.mounted
            icon: "open_in_new"
            text: Tr.tr("Open in Files")
            onClicked: Quickshell.execDetached(["xdg-open", root.mountList[0]])
        }

        RowButton {
            visible: !!root.p?.crypto && !root.locked && !root.p?.system
            icon: "lock"
            text: Tr.tr("Lock")
            subtext: Tr.tr("Unmount it first")
            disabled: root.mounted
            onClicked: Disks.run("lock", [root.p.id], Tr.tr("Lock the encrypted partition"))
        }

        TextFieldRow {
            visible: root.hasFs && !root.locked
            label: Tr.tr("Label")
            subtext: Tr.tr("What file managers call it")
            value: root.fs?.label ?? ""
            placeholderText: Tr.tr("Empty")
            onEditingFinished: v => {
                if (v !== (root.fs?.label ?? ""))
                    Disks.run("label", [root.fsTarget, v], Tr.tr("Rename the filesystem"));
            }
        }

        // ---- Mount at startup ---------------------------------------------
        SectionHeader {
            visible: root.hasFs && !root.locked && root.fs?.type !== "swap"
            text: Tr.tr("At startup")
        }

        ToggleRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: root.hasFs && !root.locked && root.fs?.type !== "swap"
            text: Tr.tr("Mount at startup")
            subtext: root.p?.system ? Tr.tr("The system's own: managed by the system") : entry ? Tr.tr("At %1").arg(entry.dir) : Tr.tr("Off: mounted only when opened")
            checked: !!entry
            enabled: !root.p?.system
            onToggled: {
                if (checked) {
                    const name = (root.fs.label || root.fs.uuid.slice(0, 8)).replace(/[^A-Za-z0-9._-]/g, "_");
                    Disks.run("fstab", [root.p.id, `/mnt/${name}`, "defaults,nofail"], Tr.tr("Mount it at startup"));
                } else {
                    Disks.run("fstab-remove", [root.p.id], Tr.tr("Stop mounting it at startup"));
                }
            }
        }

        FolderPickerRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: !!entry && !root.p?.system
            label: Tr.tr("Mount folder")
            subtext: Tr.tr("Where it appears")
            value: entry?.dir ?? ""
            allowManual: true
            validate: /^\/[^\s#]*$/
            dialogTitle: Tr.tr("Select mount folder")
            onPicked: path => {
                if (entry && path !== entry.dir)
                    Disks.run("fstab", [root.p.id, path, entry.opts], Tr.tr("Change where it mounts"));
            }
        }

        ToggleRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: !!entry && !root.p?.system
            text: Tr.tr("Start cleanly if drive is unplugged")
            subtext: Tr.tr("Adds nofail so boot doesn't stall when this drive is missing")
            checked: root.hasMountOpt("nofail")
            onToggled: root.toggleMountOpt("nofail", checked)
        }

        ToggleRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: !!entry && !root.p?.system
            text: Tr.tr("Mount only when opened")
            subtext: Tr.tr("Adds noauto so the drive stays asleep until clicked in Files")
            checked: root.hasMountOpt("noauto")
            onToggled: root.toggleMountOpt("noauto", checked)
        }

        ToggleRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: !!entry && !root.p?.system
            text: Tr.tr("Read-only")
            subtext: Tr.tr("Adds ro so apps can read files without modifying them")
            checked: root.hasMountOpt("ro")
            onToggled: root.toggleMountOpt("ro", checked)
        }

        // ---- Change it ------------------------------------------------------
        SectionHeader {
            visible: !!root.p && !root.p.system
            text: Tr.tr("Change it")
        }

        // Resize or move within adjacent free space
        DialogRowButton {
            id: reshape

            readonly property string what: Tr.tr("Resize or move the partition")
            readonly property real mib: 1048576
            readonly property bool canResize: !root.p?.crypto && root.fs?.type !== "swap"
            readonly property string fsType: root.fs?.type ?? ""
            // What the helper (udisks) would refuse, refused here already, so a
            // batch doesn't stop halfway: XFS/F2FS/exFAT don't shrink, only Btrfs
            // shrinks while mounted, NTFS/FAT only grow unmounted
            readonly property bool canShrink: canResize && !["xfs", "f2fs", "exfat"].includes(fsType) && (!root.mounted || fsType === "btrfs")
            readonly property bool canGrow: canResize && fsType !== "exfat" && (!root.mounted || ["ext2", "ext3", "ext4", "btrfs", "xfs"].includes(fsType))
            readonly property bool usedKnown: (root.fs?.used ?? -1) >= 0
            readonly property int minMiB: canShrink ? Math.min(root.spanTotalMiB, Math.max(16, Math.ceil(((root.fs?.used ?? 0) * 1.05) / mib))) : root.curSizeMiB
            // Why its size is fixed here, said up front (the editor won't go past it)
            readonly property string limitText: {
                const fs = fsType.toUpperCase();
                if (!canResize)
                    return "";
                if (!canShrink && !canGrow)
                    return root.mounted ? Tr.tr("%1 can't change size while mounted: unmount it first.").arg(fs) : Tr.tr("%1 can't change size here.").arg(fs);
                if (!canShrink)
                    return root.mounted && !["xfs", "f2fs", "exfat"].includes(fsType) ? Tr.tr("%1 can only grow while mounted: unmount it to shrink it.").arg(fs) : Tr.tr("%1 can grow but not shrink.").arg(fs);
                if (!canGrow && root.growRoom > 0)
                    return Tr.tr("%1 can't grow while mounted: unmount it first.").arg(fs);
                return "";
            }
            readonly property string sizeProblem: sizeMiB > root.curSizeMiB && !canGrow ? Tr.tr("%1 can't grow while mounted: unmount it first.").arg(fsType.toUpperCase()) : sizeMiB < root.curSizeMiB && !canShrink ? (root.mounted && !["xfs", "f2fs", "exfat"].includes(fsType) ? Tr.tr("%1 can't shrink while mounted: unmount it first.").arg(fsType.toUpperCase()) : Tr.tr("%1 can't be made smaller.").arg(fsType.toUpperCase())) : ""
            property int beforeMiB: 0
            property int sizeMiB: 1

            visible: root.isPartition && !root.p?.system && (canResize || root.spanTotalMiB > root.curSizeMiB)
            rootParent: root.flickable
            openWidth: Math.min(root.flickable.width * 0.92, 540)
            openHeight: Math.min(root.flickable.height * 0.94, 460)
            icon: "open_in_full"
            label: Tr.tr("Resize or move")
            subtext: limitText && !canShrink && !(canGrow && root.growRoom > 0) && root.freeBeforeSize <= 0 ? limitText : !canResize && root.spanTotalMiB <= root.curSizeMiB ? "" : (root.growRoom > 0 || root.freeBeforeSize > 0 ? Tr.tr("Drag or type sizes to adjust space before, size, or space after") : Tr.tr("Shrink to free space"))
            header: Tr.tr("Resize or move %1").arg(root.pname)
            acceptLabel: Tr.trCtx("Add to pending", "button")
            acceptAllowed: (beforeMiB !== root.curBeforeMiB || sizeMiB !== root.curSizeMiB) && !(root.mounted && beforeMiB !== root.curBeforeMiB) && !sizeProblem && !Disks.applyingPending
            onOpenChanged: if (open) {
                beforeMiB = root.curBeforeMiB;
                sizeMiB = root.curSizeMiB;
            }
            content: Component {
                StyledFlickable {
                    clip: true
                    contentHeight: reshapeCol.implicitHeight
                    contentWidth: width

                    ColumnLayout {
                        id: reshapeCol

                        width: parent.width
                        spacing: Tokens.spacing.small

                        PartitionSpanEditor {
                            Layout.fillWidth: true
                            Layout.topMargin: Tokens.spacing.medium
                            isCreate: false
                            totalSpanMiB: root.spanTotalMiB
                            minSizeMiB: reshape.minMiB
                            origBeforeMiB: root.origBeforeMiB
                            origSizeMiB: root.origSizeMiB
                            usedMiB: (root.fs?.used ?? -1) >= 0 ? Math.round(root.fs.used / reshape.mib) : 0
                            beforeMiB: reshape.beforeMiB
                            sizeMiB: reshape.sizeMiB
                            fixedSize: !reshape.canResize
                            useLargeUnit: root.spanTotalMiB >= 1024
                            partColor: Disks.fsColor(root.p)
                            onPartColor: Disks.onFsColor(root.p)
                            partLabel: root.pname
                            onEdited: (b, s) => {
                                reshape.beforeMiB = b;
                                reshape.sizeMiB = s;
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !!reshape.sizeProblem
                            text: reshape.sizeProblem
                            color: Colours.palette.m3error
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: reshape.canShrink && !reshape.usedKnown && root.fs?.isFilesystem && reshape.sizeMiB < root.curSizeMiB
                            text: Tr.tr("It isn't mounted, so how much it holds is unknown: a size smaller than its files is refused when the changes are applied. Mount it once to see it.")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: root.mounted && reshape.beforeMiB !== root.curBeforeMiB
                            text: Tr.tr("Unmount this partition first before moving its start offset.")
                            color: Colours.palette.m3error
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: reshape.limitText ? reshape.limitText + " " + Tr.tr("Back up important files first.") : root.freeBeforeSize <= 0 && root.growRoom <= 0 ? Tr.tr("No free space beside this partition — it can only shrink. Back up important files first.") : Tr.tr("Back up important files first: moving copies partition data and a power cut can lose data.")
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            onAccepted: {
                // Unchanged parts stay exact: whole-MiB rounding must not turn a
                // resize into a move (unaligned start) or a move into a shrink
                const newOffset = beforeMiB === root.curBeforeMiB ? root.p.offset : root.spanStart + beforeMiB * mib;
                const spanEnd = root.spanStart + root.freeBeforeSize + root.p.size + root.growRoom;
                const newSize = sizeMiB === root.curSizeMiB ? root.p.size : Math.min(spanEnd - newOffset, sizeMiB * mib);
                const actions = [];
                if (newOffset !== root.p.offset)
                    actions.push(Tr.tr("move %1").arg(root.pname));
                if (newSize !== root.p.size)
                    actions.push(Tr.tr("resize %1 to %2").arg(root.pname).arg(Disks.human(newSize)));
                const summaryText = actions.length > 0 ? actions.join(Tr.tr(" & ")) : Tr.tr("Resize or move %1").arg(root.pname);
                Disks.queueChange({
                    type: "reshape",
                    driveId: root.drive.id,
                    driveBlock: root.drive.block,
                    driveDevice: root.drive.device,
                    partId: root.p.id,
                    partNumber: root.p.number,
                    oldOffset: root.p.offset,
                    oldSize: root.p.size,
                    offset: newOffset,
                    size: newSize,
                    summary: summaryText.charAt(0).toUpperCase() + summaryText.slice(1)
                });
            }
        }

        // Format: what it becomes, then a typed confirmation
        DialogRowButton {
            id: format

            readonly property string what: Tr.tr("Format the partition")
            readonly property string confirmText: root.p?.device.replace("/dev/", "") ?? ""
            property string typed

            visible: !!root.p && !root.p.system
            rootParent: root.flickable
            openWidth: Math.min(root.flickable.width * 0.9, 520)
            openHeight: Math.min(root.flickable.height * 0.95, 680)
            icon: "cleaning_services"
            label: Tr.tr("Format (erases it)")
            header: Tr.tr("Format %1").arg(root.pname)
            acceptLabel: Tr.trCtx("Add to pending", "button")
            acceptAllowed: fmtSpec.valid && typed === confirmText && !root.mounted && !Disks.applyingPending && !Disks.busy(what)

            FormatSpec {
                id: fmtSpec
            }

            onOpenChanged: if (open) {
                fmtSpec.reset(root.fs?.type && ["ext4", "btrfs", "xfs", "f2fs", "exfat", "ntfs", "vfat", "swap"].includes(root.fs.type) ? root.fs.type : "ext4");
                fmtSpec.label = root.fs?.label ?? "";
                typed = "";
            }
            content: Component {
                StyledFlickable {
                    clip: true
                    contentHeight: formatCol.implicitHeight
                    contentWidth: width

                    ColumnLayout {
                        id: formatCol

                        width: parent.width
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: Tokens.spacing.medium
                            text: root.mounted ? Tr.tr("Unmount it first.") : Tr.tr("Everything on %1 (%2) is deleted.").arg(root.p?.device ?? "").arg(Disks.human(root.p?.size ?? 0))
                            color: Colours.palette.m3error
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }

                        FormatOptions {
                            Layout.fillWidth: true
                            spec: fmtSpec
                            showErase: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: Tokens.spacing.small
                            text: Tr.tr("Type <b>%1</b> to go ahead:").arg(format.confirmText)
                            textFormat: Text.StyledText
                            font: Tokens.font.body.small
                        }

                        StyledTextField {
                            Layout.fillWidth: true
                            placeholderText: format.confirmText
                            onTextChanged: format.typed = text
                        }
                    }
                }
            }
            onAccepted: {
                const fsLabel = Disks.fsName(fmtSpec.encrypting ? "crypto_LUKS" : fmtSpec.fstype);
                Disks.queueChange({
                    type: "format",
                    driveId: root.drive.id,
                    driveBlock: root.drive.block,
                    driveDevice: root.drive.device,
                    partId: root.p.id,
                    fstype: fmtSpec.fstype,
                    label: fmtSpec.label || "",
                    flags: fmtSpec.flags.slice(),
                    encrypt: fmtSpec.encrypting,
                    passphrase: fmtSpec.encrypting ? fmtSpec.passphrase : "",
                    summary: Tr.tr("Format %1 as %2").arg(root.pname).arg(fsLabel)
                });
                fmtSpec.passphrase = "";
                fmtSpec.repeat = "";
            }
        }

        ConfirmButton {
            readonly property string what: Tr.tr("Delete the partition")

            visible: root.isPartition && !root.p?.system
            rootParent: root.flickable
            icon: "delete"
            label: Tr.tr("Delete the partition")
            header: Tr.tr("Delete %1?").arg(root.pname)
            message: root.mounted ? Tr.tr("Unmount it first.") : Tr.tr("The partition and all its files are deleted (%1). Its space becomes free space.").arg(Disks.human(root.p?.size ?? 0))
            confirmText: root.p?.device.replace("/dev/", "") ?? ""
            acceptLabel: Tr.trCtx("Add to pending", "button")
            acceptAllowed: typed === confirmText && !root.mounted && !Disks.applyingPending
            onAccepted: {
                Disks.queueChange({
                    type: "delete",
                    driveId: root.drive.id,
                    driveBlock: root.drive.block,
                    driveDevice: root.drive.device,
                    partId: root.p.id,
                    summary: Tr.tr("Delete %1 (%2)").arg(root.pname).arg(Disks.human(root.p?.size ?? 0))
                });
                root.nState.closeSubPage();
            }
        }

        // ---- Advanced & maintenance -----------------------------------------
        RowButton {
            visible: !!root.p
            groupStart: true
            icon: "tune"
            text: Tr.tr("Advanced & maintenance")
            subtext: root.fs?.type === "btrfs" ? Tr.tr("Device path, UUID, Btrfs tools, partition flags and filesystem repair") : Tr.tr("Device path, UUID, partition flags, check and repair")
            trailingIcon: root.showAdvanced ? "expand_less" : "expand_more"
            onClicked: root.showAdvanced = !root.showAdvanced
        }

        InfoRow {
            visible: root.showAdvanced && !!root.p?.device
            icon: "tag"
            label: Tr.tr("Device path")
            value: root.p?.device ?? ""
        }

        InfoRow {
            visible: root.showAdvanced && !!(root.fs?.uuid)
            icon: "fingerprint"
            label: "UUID"
            value: root.fs?.uuid ?? ""
        }

        TextFieldRow {
            visible: root.showAdvanced && root.isPartition && root.gpt
            label: Tr.tr("Partition name")
            subtext: Tr.tr("Stored in the GPT partition table")
            value: root.p?.name ?? ""
            placeholderText: Tr.tr("Empty")
            onEditingFinished: v => {
                if (v !== (root.p?.name ?? ""))
                    Disks.run("name", [root.p.id, v], Tr.tr("Rename the partition"));
            }
        }

        TextFieldRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: root.showAdvanced && !!entry && !root.p?.system
            label: Tr.tr("Raw mount options")
            subtext: Tr.tr("Comma-separated options written to /etc/fstab")
            value: entry?.opts ?? ""
            validate: /^[^\s#]+$/
            onEditingFinished: v => {
                if (entry && v !== entry.opts)
                    Disks.run("fstab", [root.p.id, entry.dir, v], Tr.tr("Change mount options"));
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Check the filesystem")
            property string result

            visible: root.showAdvanced && root.hasFs && !root.locked && !root.p?.system && root.fs?.type !== "swap"
            icon: "fact_check"
            text: what
            subtext: Disks.busy(what) ? Tr.tr("Checking…") : result || (root.mounted ? Tr.tr("Unmount it first") : Tr.tr("Looks for errors; changes nothing"))
            disabled: root.mounted || Disks.busy(what)
            onClicked: Disks.run("check", [root.fsTarget], what, (ok, out) => result = ok ? Tr.tr("No errors found") : out.includes("errors") ? Tr.tr("Errors found: repair it") : "")
        }

        RowButton {
            readonly property string what: Tr.tr("Repair the filesystem")

            visible: root.showAdvanced && root.hasFs && !root.locked && !root.p?.system && root.fs?.type !== "swap"
            icon: "build"
            text: what
            subtext: Disks.busy(what) ? Tr.tr("Repairing…") : root.mounted ? Tr.tr("Unmount it first") : Tr.tr("Fixes errors it finds")
            disabled: root.mounted || Disks.busy(what)
            onClicked: Disks.run("repair", [root.fsTarget], what)
        }

        RowButton {
            visible: root.showAdvanced && root.linuxFs && !root.locked && !root.p?.system && root.mounted
            icon: "person"
            text: Tr.tr("Give my user write access")
            subtext: Tr.tr("Changes ownership of the partition's top folder so your account can write files")
            onClicked: Disks.run("take-ownership", [root.fsTarget], Tr.tr("Give my user write access"))
        }

        DialogRowButton {
            id: passBtn

            readonly property string what: Tr.tr("Change the passphrase")
            property string oldPass
            property string newPass
            property string repeat

            visible: root.showAdvanced && !!root.p?.crypto && !root.p?.system
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.95, 420)
            icon: "key"
            label: what
            header: what
            acceptLabel: Tr.trCtx("Change", "button")
            acceptAllowed: oldPass.length > 0 && newPass.length > 0 && newPass === repeat
            onOpenChanged: {
                oldPass = "";
                newPass = "";
                repeat = "";
            }
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledTextField {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("Current passphrase")
                        leadingIcon: "key"
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: passBtn.oldPass = text
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("New passphrase")
                        leadingIcon: "key"
                        onTextChanged: passBtn.newPass = text
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: Tr.tr("New passphrase again")
                        leadingIcon: "key"
                        supportingText: text.length > 0 && text !== passBtn.newPass ? Tr.tr("The two don't match yet") : ""
                        onTextChanged: passBtn.repeat = text
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                Disks.run("change-passphrase", [root.p.id], what, null, `${oldPass}\n${newPass}`);
                oldPass = "";
                newPass = "";
                repeat = "";
            }
        }

        // Btrfs: space, scrub, balance, subvolumes (the system's too)
        Loader {
            Layout.fillWidth: true
            active: root.showAdvanced && root.fs?.type === "btrfs" && root.mountList.length > 0
            visible: active
            sourceComponent: BtrfsSection {
                mountPoint: root.mountList[0]
                flickable: root.flickable
            }
        }

        SelectRow {
            visible: root.showAdvanced && root.isPartition && !root.p?.system && root.gpt
            label: Tr.tr("Partition type")
            subtext: Tr.tr("Tells systems what it's for")
            menuItems: typeItems.instances
            active: typeItems.instances.find(i => i.value === root.p?.type) ?? null
            fallbackText: root.p?.typeName || root.p?.type || ""
            onSelected: item => Disks.run("type", [root.p.id, item.value], Tr.tr("Change the partition type"))

            Variants {
                id: typeItems

                model: [["0fc63daf-8483-4772-8e79-3d69d8477de4", Tr.tr("Linux filesystem")], ["933ac7e1-2eb4-4f13-b844-0e14e2aef915", Tr.tr("Linux home")], ["0657fd6d-a4ab-43c4-84e5-0933c84b4f4f", Tr.tr("Linux swap")], ["ca7d7ccb-63ed-4c53-861c-1742536059cc", Tr.tr("Linux encrypted (LUKS)")], ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b", Tr.tr("EFI system")], ["ebd0a0a2-b9e5-4433-87c0-68b6b72699c7", Tr.tr("Microsoft basic data")]]

                MenuItem {
                    required property var modelData
                    readonly property string value: modelData[0]

                    text: modelData[1]
                }
            }
        }

        ToggleRow {
            visible: root.showAdvanced && root.isPartition && !root.p?.system && root.gpt
            text: Tr.tr("Hidden from other systems")
            subtext: Tr.tr("Windows doesn't show it")
            checked: root.p?.flagBits?.includes(62) ?? false
            onToggled: Disks.run("flags", [root.p.id, "62", checked ? "on" : "off"], Tr.tr("Change the partition flags"))
        }

        ToggleRow {
            visible: root.showAdvanced && root.isPartition && !root.p?.system && root.gpt
            text: Tr.tr("Don't mount automatically")
            subtext: Tr.tr("Systems leave it alone unless asked")
            checked: root.p?.flagBits?.includes(63) ?? false
            onToggled: Disks.run("flags", [root.p.id, "63", checked ? "on" : "off"], Tr.tr("Change the partition flags"))
        }

        ToggleRow {
            visible: root.showAdvanced && root.isPartition && !root.p?.system
            text: root.gpt ? Tr.tr("Legacy BIOS bootable") : Tr.tr("Bootable")
            subtext: Tr.tr("Only old (non-UEFI) start-up uses this")
            checked: root.p?.flagBits?.includes(root.gpt ? 2 : 7) ?? false
            onToggled: Disks.run("flags", [root.p.id, root.gpt ? "2" : "7", checked ? "on" : "off"], Tr.tr("Change the partition flags"))
        }

        ConfirmDialog {
            id: applyConfirm

            hostFlickable: root.flickable
        }
    }
}
