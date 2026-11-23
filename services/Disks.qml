pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// Drives, partitions and drive health (caelestia-disks, through udisks2),
// live while a disks page is open (open()/close() count the pages). Actions
// run through Admin: the shell's password prompt when udisks asks, progress
// on the page, a notification when one fails.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-disks`
    // [{ id, block, device, model, size, bus, table, health, partitions, free, whole, system... }]
    property var drives: []
    // udisks' running jobs: [{ operation, progress, progressValid, objects }]
    property var jobs: []
    property bool loaded
    property int users
    // Pending partition operations queued before Apply:
    // [{ id, type: "reshape"|"create"|"format"|"delete", driveId, driveBlock, driveDevice, partId, ... }]
    property var pendingChanges: []
    property bool applyingPending: false
    property string applyProgressText: ""

    // Cached storage sizes from StoragePage (avoid multi-second `du` on every visit)
    property var cachedFolders: ({})
    // When the home folders were last measured (Settings › Storage › Clean up)
    property double cachedFoldersAt: 0
    property var cachedSizes: ({})
    property int cachedOrphans: -1
    property list<string> cachedOrphanNames: []
    property double cachedAt: 0

    function open(): void {
        users++;
    }

    function close(): void {
        users = Math.max(0, users - 1);
    }

    function drive(id: string): var {
        return drives.find(d => d.id === id || d.block === id) ?? null;
    }

    // A partition (or a drive's whole-disk filesystem) by its block path
    function block(id: string): var {
        for (const d of drives) {
            const p = d.partitions.find(p => p.id === id);
            if (p)
                return p;
            if (d.whole?.id === id)
                return d.whole;
        }
        return null;
    }

    function driveOf(id: string): var {
        return drives.find(d => d.block === id || d.id === id || d.partitions.some(p => p.id === id) || d.whole?.id === id) ?? null;
    }

    // An action of caelestia-disks: done(ok, output, cancelled); input = stdin (passphrases)
    function run(action: string, args: list<string>, what: string, done: var, input): void {
        Admin.exec([helper, action, ...args], what, done, input);
    }

    function busy(what: string): bool {
        return Admin.jobs.some(j => j.what === what);
    }

    function pendingForDrive(driveId: string): var {
        return driveId ? pendingChanges.filter(op => op.driveId === driveId) : pendingChanges;
    }

    function pendingForPartition(partId: string): var {
        return partId ? pendingChanges.filter(op => op.partId === partId) : [];
    }

    function queueChange(op: var): void {
        if (applyingPending || !op)
            return;
        const next = pendingChanges.slice();
        const prev = next.length > 0 ? next[next.length - 1] : null;
        if (op.type === "reshape" && prev && prev.type === "reshape" && prev.partId === op.partId && prev.driveId === op.driveId) {
            if (op.offset === prev.oldOffset && op.size === prev.oldSize) {
                next.pop();
            } else {
                next[next.length - 1] = Object.assign({}, op, {
                    id: prev.id, // the queue tells its entries apart by id
                    oldOffset: prev.oldOffset,
                    oldSize: prev.oldSize
                });
            }
            pendingChanges = next;
            return;
        }
        const entry = Object.assign({
            id: `pending:${Date.now()}:${Math.random().toString(36).slice(2, 6)}`
        }, op);
        if (entry.type === "create" && !entry.partId)
            entry.partId = entry.id;
        next.push(entry);
        pendingChanges = next;
    }

    // Pending changes of a drive that was unplugged: dropped (nothing shows
    // them any more, and the drive may come back changed)
    function dropGoneDrives(): void {
        if (applyingPending || pendingChanges.length === 0)
            return;
        const gone = pendingChanges.filter(op => !drive(op.driveId));
        if (gone.length === 0)
            return;
        pendingChanges = pendingChanges.filter(op => !!drive(op.driveId));
        Toaster.toast(Tr.tr("Pending disk changes dropped"), Tr.trN("%n change for a drive that was disconnected", "%n changes for a drive that was disconnected", gone.length), "usb_off");
    }

    function undoPending(driveId = ""): void {
        if (applyingPending || pendingChanges.length === 0)
            return;
        if (!driveId) {
            pendingChanges = pendingChanges.slice(0, -1);
            return;
        }
        for (let i = pendingChanges.length - 1; i >= 0; --i) {
            if (pendingChanges[i].driveId === driveId) {
                const next = pendingChanges.slice();
                next.splice(i, 1);
                pendingChanges = next;
                return;
            }
        }
    }

    function clearPending(driveId = ""): void {
        if (applyingPending)
            return;
        pendingChanges = driveId ? pendingChanges.filter(op => op.driveId !== driveId) : [];
    }

    function computeFreeSpace(size: real, parts: var, table: string): var {
        const mib = 1048576;
        const out = [];
        const endLimit = size - (table === "gpt" ? mib : 0);
        let cursor = mib;
        for (const p of parts) {
            if (p.isContained)
                continue;
            if (p.offset - cursor >= mib)
                out.push({
                    offset: cursor,
                    size: p.offset - cursor
                });
            cursor = Math.max(cursor, p.offset + p.size);
            cursor = Math.floor((cursor + mib - 1) / mib) * mib;
        }
        if (endLimit - cursor >= mib)
            out.push({
                offset: cursor,
                size: Math.floor((endLimit - cursor) / mib) * mib
            });
        return out;
    }

    function previewDrive(d: var): var {
        if (!d)
            return null;
        const ops = pendingForDrive(d.id);
        if (ops.length === 0)
            return d;
        const clone = JSON.parse(JSON.stringify(d));
        let parts = clone.partitions ?? [];
        for (const op of ops) {
            if (op.type === "delete") {
                parts = parts.filter(p => p.id !== op.partId);
            } else if (op.type === "reshape") {
                parts = parts.map(p => {
                    if (p.id !== op.partId)
                        return p;
                    p.offset = op.offset;
                    p.size = op.size;
                    p.pendingOp = "reshape";
                    if (p.fs) {
                        p.fs.size = op.size;
                        if ((p.fs.used ?? -1) > op.size)
                            p.fs.used = op.size;
                    }
                    return p;
                });
            } else if (op.type === "format") {
                const applyFmt = target => {
                    target.pendingOp = "format";
                    target.crypto = op.encrypt ? {
                        unlocked: false,
                        cleartext: "",
                        inner: null
                    } : null;
                    target.fs = {
                        type: op.encrypt ? "crypto_LUKS" : op.fstype,
                        usage: "filesystem",
                        label: op.label || "",
                        uuid: "",
                        mounts: [],
                        sharedMounts: [],
                        isFilesystem: op.fstype !== "swap",
                        size: target.size,
                        used: -1,
                        fstab: []
                    };
                    target.system = "";
                };
                if (clone.whole && clone.whole.id === op.partId)
                    applyFmt(clone.whole);
                else
                    parts = parts.map(p => {
                        if (p.id === op.partId)
                            applyFmt(p);
                        return p;
                    });
            } else if (op.type === "create") {
                parts.push({
                    id: op.partId,
                    device: Tr.tr("New partition"),
                    offset: op.offset,
                    size: op.size,
                    name: op.name || "",
                    type: "",
                    typeName: "",
                    flagBits: [],
                    pendingOp: "create",
                    crypto: op.encrypt ? {
                        unlocked: false,
                        cleartext: "",
                        inner: null
                    } : null,
                    fs: {
                        type: op.encrypt ? "crypto_LUKS" : op.fstype,
                        usage: "filesystem",
                        label: op.label || "",
                        uuid: "",
                        mounts: [],
                        sharedMounts: [],
                        isFilesystem: op.fstype !== "swap",
                        size: op.size,
                        used: -1,
                        fstab: []
                    },
                    system: ""
                });
            }
        }
        parts.sort((a, b) => a.offset - b.offset);
        clone.partitions = parts;
        clone.free = clone.table ? computeFreeSpace(clone.size, parts, clone.table) : [];
        return clone;
    }

    function previewBlock(id: string): var {
        for (const d of drives) {
            const pd = previewDrive(d);
            const p = pd?.partitions?.find(x => x.id === id);
            if (p)
                return p;
            if (pd?.whole?.id === id)
                return pd.whole;
        }
        return null;
    }

    function executeOp(op: var, next: var): void {
        if (op.type === "delete") {
            run("delete", [op.partId], op.summary, ok => next(ok), "");
            return;
        }
        if (op.type === "format") {
            run("format", [op.partId, op.fstype, op.label || "", ...(op.flags ?? [])], op.summary, ok => next(ok), op.passphrase || "");
            return;
        }
        if (op.type === "create") {
            run("create", [op.driveBlock, String(op.offset), String(op.size), op.fstype, op.label || "", op.name || "", ...(op.flags ?? [])], op.summary, ok => next(ok), op.passphrase || "");
            return;
        }
        if (op.type === "reshape") {
            if (op.size < op.oldSize && op.offset !== op.oldOffset) {
                run("resize", [op.partId, String(op.size)], op.summary, ok => {
                    if (!ok) {
                        next(false);
                        return;
                    }
                    Admin.run("move-partition", [op.driveDevice, String(op.partNumber), String(op.offset)], op.summary, ok2 => next(ok2));
                }, "");
            } else if (op.size > op.oldSize && op.offset !== op.oldOffset) {
                Admin.run("move-partition", [op.driveDevice, String(op.partNumber), String(op.offset)], op.summary, ok => {
                    if (!ok) {
                        next(false);
                        return;
                    }
                    run("resize", [op.partId, String(op.size)], op.summary, ok2 => next(ok2), "");
                });
            } else if (op.offset !== op.oldOffset) {
                Admin.run("move-partition", [op.driveDevice, String(op.partNumber), String(op.offset)], op.summary, ok => next(ok));
            } else {
                run("resize", [op.partId, String(op.size)], op.summary, ok => next(ok), "");
            }
            return;
        }
        next(true);
    }

    // Is the disk still as it was when OP was queued? (the drive may have been
    // unplugged or changed by another program since.) EXPECTED: partitions this
    // batch already changed, { partId: { offset, size } }
    function queuedProblem(op: var, expected: var): string {
        if (!drive(op.driveId))
            return Tr.tr("The drive isn't connected any more");
        if (op.type === "create")
            return "";
        const b = block(op.partId);
        const cur = expected[op.partId] ?? (b ? {
            offset: b.offset,
            size: b.size
        } : null);
        if (!cur)
            return Tr.tr("The partition isn't there any more");
        if (op.type === "reshape" && (cur.offset !== op.oldOffset || cur.size !== op.oldSize))
            return Tr.tr("The partition changed since this was planned");
        return "";
    }

    function applyPending(driveId: string, done: var): void {
        if (applyingPending)
            return;
        const queue = pendingForDrive(driveId).slice();
        if (queue.length === 0) {
            if (typeof done === "function")
                done(true);
            return;
        }
        applyingPending = true;
        let idx = 0;
        const expected = {};
        const step = () => {
            if (idx >= queue.length) {
                applyingPending = false;
                applyProgressText = "";
                if (typeof done === "function")
                    done(true);
                return;
            }
            const op = queue[idx++];
            applyProgressText = op.summary;
            const problem = queuedProblem(op, expected);
            if (problem) {
                applyingPending = false;
                applyProgressText = "";
                Toaster.toast(Tr.tr("Stopped before: %1").arg(op.summary), Tr.tr("%1. Undo or clear the pending changes and plan them again.").arg(problem), "error");
                if (typeof done === "function")
                    done(false);
                return;
            }
            executeOp(op, ok => {
                if (!ok) {
                    applyingPending = false;
                    applyProgressText = "";
                    if (typeof done === "function")
                        done(false);
                    return;
                }
                if (op.type === "reshape")
                    expected[op.partId] = {
                        offset: op.offset,
                        size: op.size
                    };
                pendingChanges = pendingChanges.filter(x => x !== op && !(op.id && x.id === op.id));
                step();
            });
        };
        step();
    }

    // A running udisks job on this block (formatting, resizing...)
    function jobFor(id: string): var {
        return jobs.find(j => j.objects.includes(id)) ?? null;
    }

    function human(bytes: real): string {
        if (!(bytes >= 0))
            return "";
        const binary = Number(GlobalConfig.services.dataUnits) !== DataUnit.Decimal;
        const units = binary ? ["B", "KiB", "MiB", "GiB", "TiB", "PiB"] : ["B", "KB", "MB", "GB", "TB", "PB"];
        const k = binary ? 1024 : 1000;
        let i = 0;
        while (bytes >= k && i < units.length - 1) {
            bytes /= k;
            i++;
        }
        return `${bytes >= 100 || i === 0 ? Math.round(bytes) : bytes.toFixed(1)} ${units[i]}`;
    }

    function unitDivisor(large: bool): real {
        const dec = Number(GlobalConfig.services.dataUnits) === DataUnit.Decimal;
        if (large)
            return dec ? 1000 * 1000 * 1000 : 1073741824;
        return dec ? 1000 * 1000 : 1048576;
    }

    function unitLabel(large: bool): string {
        const dec = Number(GlobalConfig.services.dataUnits) === DataUnit.Decimal;
        if (large)
            return dec ? "GB" : "GiB";
        return dec ? "MB" : "MiB";
    }

    function formatUnitBytes(bytes: real, large: bool): string {
        const val = bytes / unitDivisor(large);
        return large ? val.toFixed(2) : String(Math.round(val));
    }

    function fsColor(p: var): color {
        if (!p)
            return Colours.palette.m3outline;
        if (p.crypto)
            return Colours.palette.m3tertiaryContainer;
        const t = p.fs?.type ?? "";
        if (p.typeName === "EFI system" || t === "vfat")
            return Colours.palette.m3tertiary;
        if (t === "ntfs" || t === "exfat")
            return Colours.palette.m3secondary;
        if (t === "btrfs" || t === "ext4" || t === "xfs" || t === "f2fs")
            return Colours.palette.m3primary;
        if (t === "swap")
            return Colours.palette.m3secondaryContainer;
        return Colours.palette.m3outline;
    }

    function onFsColor(p: var): color {
        if (!p)
            return Colours.palette.m3onSurface;
        if (p.crypto)
            return Colours.palette.m3onTertiaryContainer;
        const t = p.fs?.type ?? "";
        if (p.typeName === "EFI system" || t === "vfat")
            return Colours.palette.m3onTertiary;
        if (t === "ntfs" || t === "exfat")
            return Colours.palette.m3onSecondary;
        if (t === "btrfs" || t === "ext4" || t === "xfs" || t === "f2fs")
            return Colours.palette.m3onPrimary;
        if (t === "swap")
            return Colours.palette.m3onSecondaryContainer;
        return Colours.palette.m3onSurface;
    }

    function lockReason(p: var): string {
        if (!p)
            return "";
        if (p.system)
            return Tr.tr("Locked: used by the running system (%1)").arg(p.system);
        if (p.crypto && !p.crypto.unlocked)
            return Tr.tr("Locked: unlock with its passphrase to manage files");
        const fs = p.crypto?.inner ?? p.fs;
        const ms = [...(fs?.mounts ?? []), ...(fs?.sharedMounts ?? [])];
        if (ms.length > 0)
            return Tr.tr("Mounted at %1 · unmount first for formatting or resizing").arg(ms[0]);
        return "";
    }

    // What a filesystem type is called on the page
    function fsName(type: string): string {
        return ({
                ext4: "ext4",
                btrfs: "Btrfs",
                xfs: "XFS",
                f2fs: "F2FS",
                vfat: "FAT32",
                exfat: "exFAT",
                ntfs: "NTFS",
                swap: qsTr("Swap"),
                crypto_LUKS: qsTr("Encrypted (LUKS)"),
                LVM2_member: "LVM",
                linux_raid_member: "RAID"
            })[type] ?? (type || qsTr("Unknown"));
    }

    function driveIcon(d: var): string {
        if (!d)
            return "hard_drive";
        if (d.bus === "loop")
            return "album";
        if (d.bus === "usb" || d.removable)
            return "usb";
        if (d.nvme || d.rotation === 0)
            return "memory";
        return "hard_drive";
    }

    // "NVMe SSD", "SATA SSD", "Hard drive", "USB drive", "Disk image"
    function driveKind(d: var): string {
        if (!d)
            return "";
        if (d.bus === "loop")
            return qsTr("Disk image");
        if (d.bus === "usb")
            return qsTr("USB drive");
        if (d.nvme)
            return qsTr("NVMe SSD");
        if (d.rotation === 0)
            return qsTr("SSD");
        if (d.rotation > 0)
            return qsTr("Hard drive (%1 rpm)").arg(d.rotation);
        return qsTr("Drive");
    }

    // Friendly role-based name for a partition (e.g. Linux system (/), Windows (C:), EFI boot partition)
    function partName(p: var, d = null): string {
        if (!p)
            return "";
        const fs = p.crypto?.inner ?? p.fs;
        const mounts = [...(fs?.mounts ?? []), ...(fs?.sharedMounts ?? [])];
        const label = (fs?.label ?? "").trim();
        const gname = (p.name ?? "").trim();
        const generic = !gname || /^(Basic data partition|Linux filesystem|EFI system partition|Microsoft reserved partition|BIOS boot partition|Linux swap)$/i.test(gname);
        if (mounts.includes("/") || p.system === "/")
            return Tr.tr("Linux system (/)");
        if (mounts.includes("/home") || p.system === "/home")
            return label ? `${label} (/home)` : !generic ? `${gname} (/home)` : Tr.tr("Home (/home)");
        if (mounts.includes("/boot") || mounts.includes("/boot/efi") || p.system === "/boot")
            return Tr.tr("EFI boot partition (/boot)");
        if (p.typeName === "EFI system")
            return label ? `${label} (EFI)` : Tr.tr("EFI boot partition");
        if (p.typeName === "Microsoft reserved")
            return Tr.tr("Microsoft reserved (hidden, leave it)");
        if (p.typeName === "Windows recovery")
            return Tr.tr("Windows recovery");
        if (p.fs?.type === "swap")
            return label || Tr.tr("Swap");
        if (label)
            return mounts.length > 0 ? `${label} (${mounts[0]})` : label;
        if (mounts.length > 0) {
            const mp = mounts[0];
            const seg = mp.split("/").filter(Boolean).pop() ?? mp;
            if (mp.startsWith("/mnt/") || mp.startsWith("/run/media/"))
                return seg.length === 1 ? Tr.tr("Drive %1 (%2)").arg(seg.toUpperCase()).arg(mp) : `${seg} (${mp})`;
            return mp;
        }
        const drv = d ?? driveOf(p.id);
        if (p.fs?.type === "ntfs" && generic && drv && (drv.partitions ?? []).some(x => x.typeName === "Microsoft reserved" || x.typeName === "Windows recovery")) {
            const firstNtfs = drv.partitions.find(x => x.fs?.type === "ntfs" && x.typeName !== "Windows recovery" && !((x.fs?.mounts ?? []).length));
            if (firstNtfs && firstNtfs.id === p.id)
                return Tr.tr("Windows (C:)");
        }
        if (!generic)
            return gname;
        if (p.fs?.type)
            return Tr.tr("%1 partition").arg(fsName(p.fs.type));
        return p.typeName || Tr.tr("Partition");
    }

    Process {
        id: watch

        running: root.users > 0
        command: [root.helper, "watch"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                try {
                    const snap = JSON.parse(line);
                    root.drives = snap.drives ?? [];
                    root.jobs = snap.jobs ?? [];
                    root.loaded = true;
                    root.dropGoneDrives();
                } catch (e) {
                    console.warn("Disks: bad snapshot", e);
                }
            }
        }
        // Restarts if it ever stops while a page is open
        onExited: if (root.users > 0)
            restart.start()
    }

    Timer {
        id: restart

        interval: 2000
        onTriggered: if (root.users > 0)
            watch.running = true
    }
}
