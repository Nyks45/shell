pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

    // Cached storage sizes from StoragePage (avoid multi-second `du` on every visit)
    property var cachedFolders: ({})
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
