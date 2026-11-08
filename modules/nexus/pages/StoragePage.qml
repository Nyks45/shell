pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
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

    // Folder -> bytes
    property var folders: ({})
    property var sizes: ({})
    property int orphans: -1
    property bool trashConfirm
    property bool paruConfirm

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
        sizesProc.running = true;
        foldersProc.running = true;
    }

    title: Tr.tr("Storage")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Cleanup sizes (bytes; -1 when it can't be read)
        Process {
            id: sizesProc

            running: true
            command: ["sh", "-c", `
s() { v=$(du -sb "$1" 2>/dev/null | cut -f1); echo "\${v:-0}"; }
echo "trash=$(s "\${XDG_DATA_HOME:-$HOME/.local/share}/Trash")"
echo "thumbs=$(s "\${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails")"
echo "pkg=$(s /var/cache/pacman/pkg)"
echo "paru=$(s "\${XDG_CACHE_HOME:-$HOME/.cache}/paru")"
echo "journal=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]?' | head -1)"
echo "orphans=$(pacman -Qdtq 2>/dev/null | wc -l)"
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
                        } else {
                            sizes[k] = parseInt(v);
                        }
                    }
                    root.sizes = sizes;
                }
            }
        }

        // The big folders in home (du is slow on big trees: low priority, in the background)
        Process {
            id: foldersProc

            running: true
            command: ["sh", "-c", `
cd "$HOME" || exit
for d in Downloads Documents Pictures Videos Music Desktop .cache .local/share/Steam .local/share .var/app Games; do
    [ -d "$d" ] && printf '%s\\t%s\\n' "$d" "$(nice -n 19 ionice -c3 du -sxb "$d" 2>/dev/null | cut -f1)"
done
`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const folders = {};
                    for (const line of text.split("\n")) {
                        const [name, size] = line.split("\t");
                        if (name && size)
                            folders[name] = parseInt(size);
                    }
                    // .local/share without Steam (listed apart)
                    if (folders[".local/share"] && folders[".local/share/Steam"])
                        folders[".local/share"] -= folders[".local/share/Steam"];
                    root.folders = folders;
                }
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

        Timer {
            id: paruConfirmTimer

            interval: 4000
            onTriggered: root.paruConfirm = false
        }

        Timer {
            id: trashConfirmTimer

            interval: 4000
            onTriggered: root.trashConfirm = false
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

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: Object.keys(root.folders).length === 0
            text: Tr.tr("Measuring folders…")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
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
            text: root.trashConfirm ? Tr.tr("Click again to empty the Trash") : Tr.tr("Empty the Trash")
            subtext: root.trashConfirm ? Tr.tr("Deleted files can't be brought back") : root.sizes.trash > 0 ? Tr.tr("%1 in the Trash").arg(root.human(root.sizes.trash)) : Tr.tr("The Trash is empty")
            disabled: !(root.sizes.trash > 0)
            onClicked: {
                if (!root.trashConfirm) {
                    root.trashConfirm = true;
                    trashConfirmTimer.restart();
                    return;
                }
                root.trashConfirm = false;
                Quickshell.execDetached(["gio", "trash", "--empty"]);
                refreshTimer.left = 1;
                refreshTimer.restart();
            }
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
            subtext: busy ? Tr.tr("Cleaning…") : Tr.tr("%1 of downloaded packages; keeps the latest of each").arg(root.human(root.sizes.pkg ?? 0))
            disabled: busy
            onClicked: Admin.run("clean-package-cache", [], what, () => root.refresh())
        }

        RowButton {
            visible: (root.sizes.paru ?? 0) > 0
            icon: "build"
            text: Tr.tr("Clear AUR build files")
            subtext: root.paruConfirm ? Tr.tr("Click again: packages are then rebuilt from scratch on their next update") : Tr.tr("%1 that paru keeps from building AUR packages").arg(root.human(root.sizes.paru ?? 0))
            onClicked: {
                if (!root.paruConfirm) {
                    root.paruConfirm = true;
                    paruConfirmTimer.restart();
                    return;
                }
                root.paruConfirm = false;
                Quickshell.execDetached(["sh", "-c", `rm -rf "\${XDG_CACHE_HOME:-$HOME/.cache}/paru/clone"`]);
                refreshTimer.left = 2;
                refreshTimer.restart();
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Remove unused packages")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            icon: "remove_selection"
            text: what
            subtext: busy ? Tr.tr("Removing…") : root.orphans === 0 ? Tr.tr("None") : Tr.tr("%1 installed as dependencies of packages that are gone").arg(root.orphans)
            disabled: root.orphans === 0 || busy
            onClicked: Admin.run("remove-orphans", [], what, () => root.refresh())
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
    }
}
