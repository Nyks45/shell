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
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common
import qs.modules.nexus.pages.disks

// Storage: the drives (each unfolds to its partitions, free space, health and
// what a partition manager does), what takes room in the home folder, and
// cleaning up (Trash, thumbnails, package caches, unused packages, old logs).
// System changes ask for the password in the shell's own prompt.
PageBase {
    id: root

    // Folder -> bytes (seeded from Disks cache so revisiting is instant)
    property var folders: Object.assign({}, Disks.cachedFolders)
    property var sizes: Object.assign({}, Disks.cachedSizes)
    property int orphans: Disks.cachedOrphans
    property list<string> orphanNames: Disks.cachedOrphanNames
    property var _scanFolders: ({})
    property bool measuringFolders

    function human(bytes: real): string {
        if (!(bytes >= 0))
            return "";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return `${bytes >= 100 || i === 0 ? Math.round(bytes) : bytes.toFixed(1)} ${units[i]}`;
    }

    function refresh(): void {
        sizesProc.running = false;
        sizesProc.running = true;
        _scanFolders = {};
        measuringFolders = true;
        foldersProc.running = false;
        foldersProc.running = true;
    }

    title: Tr.tr("Storage")

    Component.onCompleted: {
        if (!(Disks.cachedAt > 0 && (Date.now() - Disks.cachedAt) < 60000))
            refresh();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Cleanup sizes (bytes; -1 when it can't be read)
        Process {
            id: sizesProc

            running: false
            command: ["sh", "-c", `
s() { v=$(du -sb "$1" 2>/dev/null | cut -f1); echo "\${v:-0}"; }
echo "trash=$(s "\${XDG_DATA_HOME:-$HOME/.local/share}/Trash")"
echo "thumbs=$(s "\${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails")"
echo "pkg=$(s /var/cache/pacman/pkg)"
echo "paru=$(s "\${XDG_CACHE_HOME:-$HOME/.cache}/paru")"
echo "journal=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]?' | head -1)"
echo "orphans=$(pacman -Qdtq 2>/dev/null | wc -l)"
echo "orphan_list=$(pacman -Qdtq 2>/dev/null | paste -sd ',' -)"
`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const sizes = {};
                    for (const line of text.split("\n")) {
                        const [k, v] = line.split("=");
                        if (!k || v === undefined)
                            continue;
                        if (k === "journal") {
                            const m = v.match(/([0-9.]+)([KMGT]?)/);
                            sizes.journal = m ? parseFloat(m[1]) * ({
                                        "": 1,
                                        K: 1024,
                                        M: 1048576,
                                        G: 1073741824,
                                        T: 1099511627776
                                    })[m[2]] : -1;
                        } else if (k === "orphans") {
                            root.orphans = parseInt(v);
                            Disks.cachedOrphans = root.orphans;
                        } else if (k === "orphan_list") {
                            root.orphanNames = v ? v.split(",").filter(Boolean) : [];
                            Disks.cachedOrphanNames = root.orphanNames;
                        } else {
                            sizes[k] = parseInt(v);
                        }
                    }
                    root.sizes = sizes;
                    Disks.cachedSizes = sizes;
                    Disks.cachedAt = Date.now();
                }
            }
        }

        // The big folders in home: light folders first, excluding Steam when
        // scanning .local/share so Steam is never walked twice. Results stream in.
        Process {
            id: foldersProc

            running: false
            command: ["sh", "-c", `
cd "$HOME" || exit
for d in Desktop Documents Pictures Videos Music Downloads Games .var/app .cache .local/share .local/share/Steam; do
    if [ -d "$d" ]; then
        if [ "$d" = ".local/share" ]; then
            val=$(nice -n 19 ionice -c3 du -sxb --exclude=Steam "$d" 2>/dev/null | cut -f1)
        else
            val=$(nice -n 19 ionice -c3 du -sxb "$d" 2>/dev/null | cut -f1)
        fi
        printf '%s\\t%s\\n' "$d" "$val"
    fi
done
`]
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: line => {
                    const [name, size] = line.split("\t");
                    if (!name || !size)
                        return;
                    const val = parseInt(size);
                    if (isNaN(val))
                        return;
                    const scan = Object.assign({}, root._scanFolders);
                    scan[name] = val;
                    root._scanFolders = scan;
                    const merged = Object.assign({}, root.folders, scan);
                    root.folders = merged;
                    Disks.cachedFolders = merged;
                    Disks.cachedAt = Date.now();
                }
            }
            onExited: {
                root.measuringFolders = false;
                root.folders = Object.assign({}, root._scanFolders);
                Disks.cachedFolders = root.folders;
                Disks.cachedAt = Date.now();
            }
        }

        // Re-read after a cleanup (it may still be running in its terminal)
        Timer {
            id: refreshTimer

            interval: 4000
            repeat: true
            property int left
            onTriggered: {
                root.refresh();
                if (--left <= 0)
                    stop();
            }
        }

        SectionHeader {
            first: true
            text: Tr.tr("Drives")
        }

        // Each drive, unfolding to its partitions, free space, health and actions
        DriveCards {
            Layout.fillWidth: true
            nState: root.nState
            flickable: root.flickable
        }

        SectionHeader {
            text: Tr.tr("Home folder")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.measuringFolders
            spacing: Tokens.spacing.small

            LoadingIndicator {
                implicitSize: Tokens.font.body.small.pointSize * 1.4
            }

            StyledText {
                Layout.fillWidth: true
                text: Object.keys(root.folders).length === 0 ? Tr.tr("Measuring folders…") : Tr.tr("Measuring remaining folders…")
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }
        }

        Repeater {
            id: folderList

            model: Object.entries(root.folders).filter(([, size]) => size > 0).sort((a, b) => b[1] - a[1])

            RowButton {
                required property var modelData
                required property int index

                readonly property var names: ({
                        Downloads: Tr.tr("Downloads"),
                        Documents: Tr.tr("Documents"),
                        Pictures: Tr.tr("Pictures"),
                        Videos: Tr.tr("Videos"),
                        Music: Tr.tr("Music"),
                        Desktop: Tr.tr("Desktop"),
                        ".cache": Tr.tr("App caches"),
                        ".local/share/Steam": Tr.tr("Steam (games)"),
                        ".local/share": Tr.tr("App data"),
                        ".var/app": Tr.tr("Flatpak app data"),
                        Games: Tr.tr("Games")
                    })

                icon: modelData[0].startsWith(".") ? "folder_special" : "folder"
                text: names[modelData[0]] ?? modelData[0]
                subtext: `${root.human(modelData[1])} · ~/${modelData[0]}`
                trailingIcon: "open_in_new"
                onClicked: Quickshell.execDetached(["xdg-open", `${Paths.home}/${modelData[0]}`])
            }
        }

        SectionHeader {
            text: Tr.tr("Clean up")
        }

        RowButton {
            icon: "delete"
            text: Tr.tr("Empty the Trash")
            subtext: root.sizes.trash > 0 ? Tr.tr("%1 in the Trash").arg(root.human(root.sizes.trash)) : Tr.tr("The Trash is empty")
            disabled: !(root.sizes.trash > 0)
            onClicked: confirmDialog.ask({
                header: Tr.tr("Empty the Trash?"),
                body: Tr.tr("Permanently deletes %1 currently in the Trash.").arg(root.human(root.sizes.trash)),
                warning: Tr.tr("Deleted files can't be brought back."),
                confirmLabel: Tr.tr("Empty Trash"),
                onConfirm: () => {
                    Quickshell.execDetached(["gio", "trash", "--empty"]);
                    refreshTimer.left = 1;
                    refreshTimer.restart();
                }
            })
        }

        RowButton {
            icon: "image"
            text: Tr.tr("Clear thumbnails")
            subtext: root.sizes.thumbs > 0 ? Tr.tr("%1; apps make them again when needed").arg(root.human(root.sizes.thumbs)) : Tr.tr("Nothing to clear")
            disabled: !(root.sizes.thumbs > 0)
            onClicked: {
                Quickshell.execDetached(["sh", "-c", `rm -rf "\${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails"`]);
                refreshTimer.left = 1;
                refreshTimer.restart();
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Clean the package cache")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            icon: "inventory_2"
            text: what
            subtext: busy ? Tr.tr("Cleaning…") : Tr.tr("%1 of downloaded packages; keeps the 3 newest versions of each").arg(root.human(root.sizes.pkg ?? 0))
            disabled: busy
            onClicked: Admin.run("clean-package-cache", [], what, () => root.refresh())
        }

        RowButton {
            visible: (root.sizes.paru ?? 0) > 0
            icon: "build"
            text: Tr.tr("Clear AUR build files")
            subtext: Tr.tr("%1 that paru keeps from building AUR packages").arg(root.human(root.sizes.paru ?? 0))
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear AUR build files?"),
                body: Tr.tr("Deletes %1 of cached AUR build directories. Packages will rebuild from scratch on their next update.").arg(root.human(root.sizes.paru ?? 0)),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["sh", "-c", `rm -rf "\${XDG_CACHE_HOME:-$HOME/.cache}/paru/clone"`]);
                    refreshTimer.left = 2;
                    refreshTimer.restart();
                }
            })
        }

        RowButton {
            readonly property string what: Tr.tr("Remove unused packages")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            icon: "remove_selection"
            text: what
            subtext: busy ? Tr.tr("Removing…") : root.orphans === 0 ? Tr.tr("None") : Tr.tr("%1 installed as dependencies of packages that are gone").arg(root.orphans)
            disabled: root.orphans === 0 || busy
            onClicked: {
                const shown = root.orphanNames.slice(0, 25).join(", ");
                const extra = root.orphanNames.length > 25 ? Tr.tr(" … and %1 more").arg(root.orphanNames.length - 25) : "";
                confirmDialog.ask({
                    header: Tr.tr("Remove %1 unused packages?").arg(root.orphans),
                    body: shown ? Tr.tr("Packages to remove: %1%2").arg(shown).arg(extra) : Tr.tr("%1 unused dependency packages will be removed.").arg(root.orphans),
                    confirmLabel: Tr.tr("Remove"),
                    onConfirm: () => Admin.run("remove-orphans", [], what, () => root.refresh())
                });
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Trim system logs")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            icon: "receipt_long"
            text: what
            subtext: busy ? Tr.tr("Trimming…") : Tr.tr("%1 of logs; keeps the last two weeks").arg(root.human(root.sizes.journal ?? 0))
            disabled: busy
            onClicked: Admin.run("journal-vacuum", ["2weeks"], what, () => root.refresh())
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}
