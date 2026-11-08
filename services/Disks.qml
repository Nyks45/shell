pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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
        const units = ["B", "KB", "MB", "GB", "TB", "PB"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return `${bytes >= 100 || i === 0 ? Math.round(bytes) : bytes.toFixed(1)} ${units[i]}`;
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

    // A name for a partition: its label, else the partition's name, else the type
    function partName(p: var): string {
        const fs = p.crypto?.inner ?? p.fs;
        return fs?.label || p.name || p.typeName || fsName(p.fs?.type ?? "");
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
