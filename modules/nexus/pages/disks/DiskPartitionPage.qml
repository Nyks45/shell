pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// One partition (or a drive's whole-disk filesystem): what is on it and
// everything a partition manager does with it. The system's own partitions
// (/, /boot, /home...) show what they are but can't be erased or reshaped.
PageBase {
    id: root

    readonly property var p: Disks.block(nState.selectedPartition)
    readonly property var drive: Disks.driveOf(nState.selectedPartition)
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
    // Free space right after it (what it can grow into)
    readonly property real growRoom: {
        if (!isPartition || !drive)
            return 0;
        const end = p.offset + p.size;
        const gap = drive.free.find(f => f.offset >= end && f.offset < end + 1048576);
        return gap ? gap.offset + gap.size - end : 0;
    }
    readonly property string pname: p ? Disks.partName(p) : ""
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
                    text: root.p ? [Disks.fsName(root.p.fs.type), root.p.crypto ? (root.locked ? Tr.tr("locked") : Disks.fsName(root.fs?.type ?? "")) : "", Disks.human(root.p.size), root.p.device].filter(x => x).join(" · ") : ""
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
                    text: [root.mounted ? Tr.tr("Open at %1").arg(root.mountList.join(", ")) : Tr.tr("Not mounted"), root.p?.typeName ? Tr.tr("type: %1").arg(root.p.typeName) : "", root.fs?.uuid ? `UUID ${root.fs.uuid}` : ""].filter(x => x).join(" · ")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAnywhere
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
                    visible: !!root.p?.system
                    text: Tr.tr("The running system uses this (%1): it can't be formatted, deleted or resized from here.").arg(root.p?.system ?? "")
                    color: Colours.palette.m3onSurfaceVariant
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

        // ---- Names ---------------------------------------------------------
        SectionHeader {
            visible: !!root.p && (root.hasFs || root.isPartition)
            text: Tr.tr("Names")
        }

        TextFieldRow {
            visible: root.hasFs && !root.locked
            label: Tr.tr("Label")
            subtext: Tr.tr("What file managers call it")
            value: root.fs?.label ?? ""
            placeholderText: Tr.tr("No label")
            onEditingFinished: v => {
                if (v !== (root.fs?.label ?? ""))
                    Disks.run("label", [root.fsTarget, v], Tr.tr("Rename the filesystem"));
            }
        }

        TextFieldRow {
            visible: root.isPartition && root.gpt
            label: Tr.tr("Partition name")
            subtext: Tr.tr("Stored in the partition table")
            value: root.p?.name ?? ""
            placeholderText: Tr.tr("No name")
            onEditingFinished: v => {
                if (v !== (root.p?.name ?? ""))
                    Disks.run("name", [root.p.id, v], Tr.tr("Rename the partition"));
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

        TextFieldRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: !!entry && !root.p?.system
            label: Tr.tr("Folder")
            subtext: Tr.tr("Where it appears")
            value: entry?.dir ?? ""
            validate: /^\/[^\s#]*$/
            onEditingFinished: v => {
                if (entry && v !== entry.dir)
                    Disks.run("fstab", [root.p.id, v, entry.opts], Tr.tr("Change where it mounts"));
            }
        }

        TextFieldRow {
            readonly property var entry: root.fs?.fstab[0] ?? null

            visible: !!entry && !root.p?.system
            label: Tr.tr("Options")
            subtext: Tr.tr("nofail: start even when it's missing; noauto: only when opened; ro: read-only")
            value: entry?.opts ?? ""
            validate: /^[^\s#]+$/
            onEditingFinished: v => {
                if (entry && v !== entry.opts)
                    Disks.run("fstab", [root.p.id, entry.dir, v], Tr.tr("Change the mount options"));
            }
        }

        // ---- Maintenance ---------------------------------------------------
        SectionHeader {
            visible: !!root.p && !root.p.system
            text: Tr.tr("Maintenance")
        }

        RowButton {
            readonly property string what: Tr.tr("Check the filesystem")
            property string result

            visible: root.hasFs && !root.locked && !root.p?.system && root.fs?.type !== "swap"
            icon: "fact_check"
            text: what
            subtext: Disks.busy(what) ? Tr.tr("Checking…") : result || (root.mounted ? Tr.tr("Unmount it first") : Tr.tr("Looks for errors; changes nothing"))
            disabled: root.mounted || Disks.busy(what)
            onClicked: Disks.run("check", [root.fsTarget], what, (ok, out) => result = ok ? Tr.tr("No errors found") : out.includes("errors") ? Tr.tr("Errors found: repair it") : "")
        }

        RowButton {
            readonly property string what: Tr.tr("Repair the filesystem")

            visible: root.hasFs && !root.locked && !root.p?.system && root.fs?.type !== "swap"
            icon: "build"
            text: what
            subtext: Disks.busy(what) ? Tr.tr("Repairing…") : root.mounted ? Tr.tr("Unmount it first") : Tr.tr("Fixes errors it finds")
            disabled: root.mounted || Disks.busy(what)
            onClicked: Disks.run("repair", [root.fsTarget], what)
        }

        RowButton {
            visible: root.linuxFs && !root.locked && !root.p?.system && root.mounted
            icon: "person"
            text: Tr.tr("Make it mine")
            subtext: Tr.tr("Its top folder becomes yours, so you can save files there")
            onClicked: Disks.run("take-ownership", [root.fsTarget], Tr.tr("Make the filesystem yours"))
        }

        DialogRowButton {
            id: passBtn

            readonly property string what: Tr.tr("Change the passphrase")
            property string oldPass
            property string newPass
            property string repeat

            visible: !!root.p?.crypto && !root.p?.system
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

        // ---- Btrfs: space, scrub, balance, subvolumes (the system's too) ----
        Loader {
            Layout.fillWidth: true
            active: root.fs?.type === "btrfs" && root.mountList.length > 0
            visible: active
            sourceComponent: BtrfsSection {
                mountPoint: root.mountList[0]
                flickable: root.flickable
            }
        }

        // ---- Change it ------------------------------------------------------
        SectionHeader {
            visible: !!root.p && !root.p.system
            text: Tr.tr("Change it")
        }

        // Resize: within its own size and the free space right after it
        DialogRowButton {
            id: resize

            readonly property string what: Tr.tr("Resize the partition")
            readonly property real mib: 1048576
            readonly property real maxMiB: root.isPartition ? Math.floor((root.p.size + root.growRoom) / mib) : 0
            // Not below what's stored on it (plus a little room), when known
            readonly property real minMiB: Math.max(16, Math.ceil(((root.fs?.used ?? 0) * 1.05) / mib))
            property real sizeMiB

            visible: root.isPartition && !root.p?.system && !root.p?.crypto && root.fs?.type !== "swap"
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 340)
            icon: "open_in_full"
            label: what
            header: Tr.tr("Resize %1").arg(root.pname)
            acceptLabel: Tr.trCtx("Resize", "button")
            acceptAllowed: Math.round(sizeMiB) !== Math.floor(root.p.size / mib) && !Disks.busy(what)
            onOpenChanged: if (open)
                sizeMiB = Math.floor(root.p.size / mib)
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: Tr.tr("New size: %1 (now %2; up to %3)").arg(Disks.human(resize.sizeMiB * resize.mib)).arg(Disks.human(root.p.size)).arg(Disks.human(resize.maxMiB * resize.mib))
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    // StyledSlider works in 0..1, between the smallest and largest size
                    StyledSlider {
                        readonly property real lo: Math.min(resize.minMiB, resize.maxMiB)
                        readonly property real span: Math.max(1, resize.maxMiB - lo)

                        Layout.fillWidth: true
                        implicitHeight: Tokens.padding.large * 2
                        value: (resize.sizeMiB - lo) / span
                        onInteraction: v => resize.sizeMiB = Math.round(lo + v * span)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.growRoom > 0 ? Tr.tr("It can grow into the free space right after it. Back up important files first: a power cut while resizing can lose data.") : Tr.tr("No free space right after it: it can only shrink. Back up important files first.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: Disks.run("resize", [root.p.id, String(Math.min(root.p.size + root.growRoom, sizeMiB * mib))], what)
        }

        // Move: same size, into the free space before or after it
        DialogRowButton {
            id: move

            readonly property string what: Tr.tr("Move the partition")
            readonly property real mib: 1048576
            property real start

            visible: root.isPartition && !root.p?.system && (root.moveFrom < root.p.offset || root.moveTo > root.p.offset)
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 360)
            icon: "swap_horiz"
            label: what
            header: Tr.tr("Move %1").arg(root.pname)
            acceptLabel: Tr.trCtx("Move", "button")
            acceptAllowed: !root.mounted && Math.round(start / mib) !== Math.round(root.p.offset / mib) && !Disks.busy(what)
            onOpenChanged: if (open)
                start = root.p.offset
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: root.mounted ? Tr.tr("Unmount it first.") : Tr.tr("Starts at %1 (now %2); its size stays %3").arg(Disks.human(move.start)).arg(Disks.human(root.p.offset)).arg(Disks.human(root.p.size))
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    // StyledSlider works in 0..1, over where it can start
                    StyledSlider {
                        readonly property real span: Math.max(move.mib, root.moveTo - root.moveFrom)

                        Layout.fillWidth: true
                        implicitHeight: Tokens.padding.large * 2
                        value: (move.start - root.moveFrom) / span
                        onInteraction: v => move.start = root.moveFrom + Math.round(v * span / move.mib) * move.mib
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("All its data is copied to the new place: this takes a while, and a power cut during it can lose the partition. Back it up first. Systems that start from it may need their boot entry updated.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: Admin.run("move-partition", [root.drive.device, String(root.p.number), String(Math.round(start / mib) * mib)], what)
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
            acceptLabel: Tr.trCtx("Format", "button")
            acceptAllowed: fmtSpec.valid && typed === confirmText && !root.mounted && !Disks.busy(what)

            FormatSpec {
                id: fmtSpec
            }

            onOpenChanged: if (open) {
                fmtSpec.reset(root.fs?.type && ["ext4", "btrfs", "xfs", "f2fs", "exfat", "ntfs", "vfat", "swap"].includes(root.fs.type) ? root.fs.type : "ext4");
                fmtSpec.label = root.fs?.label ?? "";
                typed = "";
            }
            content: Component {
                ColumnLayout {
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

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: {
                Disks.run("format", [root.p.id, fmtSpec.fstype, fmtSpec.label || "", ...fmtSpec.flags], what, null, fmtSpec.encrypting ? fmtSpec.passphrase : "");
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
            acceptLabel: Tr.trCtx("Delete", "button")
            onAccepted: Disks.run("delete", [root.p.id], what, ok => {
                if (ok)
                    root.nState.closeSubPage();
            })
        }

        // ---- Advanced --------------------------------------------------------
        SectionHeader {
            visible: root.isPartition && !root.p?.system
            text: Tr.tr("Advanced")
        }

        SelectRow {
            visible: root.isPartition && !root.p?.system && root.gpt
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
            visible: root.isPartition && !root.p?.system && root.gpt
            text: Tr.tr("Hidden from other systems")
            subtext: Tr.tr("Windows doesn't show it")
            checked: root.p?.flagBits?.includes(62) ?? false
            onToggled: Disks.run("flags", [root.p.id, "62", checked ? "on" : "off"], Tr.tr("Change the partition flags"))
        }

        ToggleRow {
            visible: root.isPartition && !root.p?.system && root.gpt
            text: Tr.tr("Don't mount automatically")
            subtext: Tr.tr("Systems leave it alone unless asked")
            checked: root.p?.flagBits?.includes(63) ?? false
            onToggled: Disks.run("flags", [root.p.id, "63", checked ? "on" : "off"], Tr.tr("Change the partition flags"))
        }

        ToggleRow {
            visible: root.isPartition && !root.p?.system
            text: root.gpt ? Tr.tr("Legacy BIOS bootable") : Tr.tr("Bootable")
            subtext: Tr.tr("Only old (non-UEFI) start-up uses this")
            checked: root.p?.flagBits?.includes(root.gpt ? 2 : 7) ?? false
            onToggled: Disks.run("flags", [root.p.id, root.gpt ? "2" : "7", checked ? "on" : "off"], Tr.tr("Change the partition flags"))
        }
    }
}
