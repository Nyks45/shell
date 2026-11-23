pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Storage › Clean up: Home folder usage with proportional bars plus safe, confirmed cleanup actions.
PageBase {
    id: root

    property var folders: Object.assign({}, Disks.cachedFolders)
    property var sizes: Object.assign({}, Disks.cachedSizes)
    property int orphans: Disks.cachedOrphans
    property list<string> orphanNames: Disks.cachedOrphanNames
    property var _scanFolders: ({})
    property bool measuringFolders

    readonly property var sortedFolders: Object.entries(root.folders).filter(([, size]) => size > 0).sort((a, b) => b[1] - a[1])
    readonly property real maxFolderSize: sortedFolders.length > 0 ? sortedFolders[0][1] : 1

    // The cleanup sizes are cheap; measuring the home folders (du over all of
    // it, Steam included) is not: only after a change there (homeChanged) or
    // when the last measure is over 10 minutes old
    function refresh(homeChanged: bool): void {
        sizesProc.running = false;
        sizesProc.running = true;
        if (homeChanged || !(Date.now() - Disks.cachedFoldersAt < 600000))
            measureHome();
    }

    function measureHome(): void {
        _scanFolders = {};
        measuringFolders = true;
        foldersProc.running = false;
        foldersProc.running = true;
    }

    title: Tr.tr("Clean up")

    Component.onCompleted: {
        if (!(Disks.cachedAt > 0 && (Date.now() - Disks.cachedAt) < 60000))
            refresh(false);
        else if (!(Date.now() - Disks.cachedFoldersAt < 600000))
            measureHome();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Cleanup sizes (bytes; -1 when unavailable)
        Process {
            id: sizesProc

            running: false
            command: ["sh", "-c", `
s() { v=$(du -sb "$1" 2>/dev/null | cut -f1); echo "\${v:-0}"; }
echo "trash=$(s "\${XDG_DATA_HOME:-$HOME/.local/share}/Trash")"
echo "thumbs=$(s "\${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails")"
echo "pkg=$(s /var/cache/pacman/pkg)"
echo "paru=$(s "\${XDG_CACHE_HOME:-$HOME/.cache}/paru")"
echo "coredump=$(s /var/lib/systemd/coredump)"
echo "journal=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]?' | head -1)"
echo "orphans=$(pacman -Qdtq 2>/dev/null | wc -l)"
echo "orphan_list=$(pacman -Qdtq 2>/dev/null | paste -sd ',' -)"
command -v flatpak >/dev/null && echo "has_flatpak=1" || echo "has_flatpak=0"
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

        // Home folder usage scan (excluding Steam inside .local/share so Steam is not double-counted)
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
                Disks.cachedFoldersAt = Date.now();
                Disks.cachedAt = Date.now();
            }
        }

        Timer {
            id: refreshTimer

            interval: 4000
            repeat: true
            property int left
            // Used by the actions that delete files in the home folder
            onTriggered: {
                root.refresh(true);
                if (--left <= 0)
                    stop();
            }
        }

        SectionHeader {
            text: Tr.tr("Home folder")
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: root.measuringFolders
            implicitHeight: measuringRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: measuringRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

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
        }

        Repeater {
            id: folderList

            model: root.sortedFolders

            ConnectedRect {
                id: frow

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

                Layout.fillWidth: true
                implicitHeight: fCol.implicitHeight + Tokens.padding.medium * 2

                StateLayer {
                    onClicked: Quickshell.execDetached(["xdg-open", `${Paths.home}/${frow.modelData[0]}`])
                }

                ColumnLayout {
                    id: fCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: frow.modelData[0].startsWith(".") ? "folder_special" : "folder"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: frow.names[frow.modelData[0]] ?? frow.modelData[0]
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: Disks.human(frow.modelData[1])
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }

                        MaterialIcon {
                            text: "open_in_new"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.small
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        value: root.maxFolderSize > 0 ? Math.min(1, frow.modelData[1] / root.maxFolderSize) : 0
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Clean up")
        }

        RowButton {
            icon: "delete"
            text: Tr.tr("Empty the Trash")
            subtext: root.sizes.trash > 0 ? Tr.tr("%1 in the Trash").arg(Disks.human(root.sizes.trash)) : Tr.tr("The Trash is empty")
            disabled: !(root.sizes.trash > 0)
            onClicked: confirmDialog.ask({
                header: Tr.tr("Empty the Trash?"),
                body: Tr.tr("Permanently deletes %1 currently in the Trash.").arg(Disks.human(root.sizes.trash)),
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
            subtext: root.sizes.thumbs > 0 ? Tr.tr("%1; apps make them again when needed").arg(Disks.human(root.sizes.thumbs)) : Tr.tr("Nothing to clear")
            disabled: !(root.sizes.thumbs > 0)
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear thumbnail cache?"),
                body: Tr.tr("Deletes %1 of cached image and video preview thumbnails. Apps recreate them as needed.").arg(Disks.human(root.sizes.thumbs)),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => {
                    Quickshell.execDetached(["sh", "-c", `rm -rf "\${XDG_CACHE_HOME:-$HOME/.cache}/thumbnails"/*`]);
                    Toaster.toast(Tr.tr("Thumbnail cache cleared"), "", "image");
                    refreshTimer.left = 1;
                    refreshTimer.restart();
                }
            })
        }

        RowButton {
            readonly property string what: Tr.tr("Clean the package cache")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            icon: "inventory_2"
            text: what
            subtext: busy ? Tr.tr("Cleaning…") : Tr.tr("%1 of downloaded packages; keeps the 3 newest versions of each").arg(Disks.human(root.sizes.pkg ?? 0))
            disabled: busy
            onClicked: Admin.run("clean-package-cache", [], what, () => root.refresh(false))
        }

        RowButton {
            visible: (root.sizes.paru ?? 0) > 0
            icon: "build"
            text: Tr.tr("Clear AUR build files")
            subtext: Tr.tr("%1 that paru keeps from building AUR packages").arg(Disks.human(root.sizes.paru ?? 0))
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear AUR build files?"),
                body: Tr.tr("Deletes %1 of cached AUR build directories. Packages will rebuild from scratch on their next update.").arg(Disks.human(root.sizes.paru ?? 0)),
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
            disabled: root.orphans === 0 || busy || orphanCheck.running
            // The list is read again first (the one shown may be minutes old;
            // the helper removes what is unused at that moment)
            onClicked: orphanCheck.running = true

            Process {
                id: orphanCheck

                command: ["pacman", "-Qdtq"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const names = text.split("\n").map(n => n.trim()).filter(Boolean);
                        root.orphanNames = names;
                        root.orphans = names.length;
                        Disks.cachedOrphanNames = names;
                        Disks.cachedOrphans = names.length;
                        if (names.length === 0)
                            return;
                        const shown = names.slice(0, 25).join(", ");
                        const extra = names.length > 25 ? Tr.tr(" … and %1 more").arg(names.length - 25) : "";
                        confirmDialog.ask({
                            header: Tr.tr("Remove %1 unused packages?").arg(names.length),
                            body: Tr.tr("Packages to remove: %1%2").arg(shown).arg(extra),
                            warning: Tr.tr("Dependencies that only these packages needed are removed too."),
                            confirmLabel: Tr.tr("Remove"),
                            onConfirm: () => Admin.run("remove-orphans", [], Tr.tr("Remove unused packages"), () => root.refresh(false))
                        });
                    }
                }
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Remove unused Flatpak runtimes")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            visible: (root.sizes.has_flatpak ?? 0) === 1
            icon: "layers_clear"
            text: what
            subtext: busy ? Tr.tr("Removing…") : Tr.tr("Runtimes no installed Flatpak app uses any more")
            disabled: busy
            onClicked: confirmDialog.ask({
                header: Tr.tr("Remove unused Flatpak runtimes?"),
                body: Tr.tr("Uninstalls old Flatpak runtimes and extensions no longer needed by any installed Flatpak app."),
                confirmLabel: Tr.tr("Remove"),
                onConfirm: () => Admin.exec(["flatpak", "uninstall", "--unused", "--assumeyes"], what, ok => {
                    if (ok)
                        Toaster.toast(Tr.tr("Unused Flatpak runtimes removed"), "", "layers_clear");
                    root.refresh(false);
                })
            })
        }

        RowButton {
            readonly property string what: Tr.tr("Clear crash dumps")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            visible: (root.sizes.coredump ?? 0) > 0
            icon: "bug_report"
            text: what
            subtext: busy ? Tr.tr("Clearing…") : Tr.tr("%1 of saved app crash reports in /var/lib/systemd/coredump").arg(Disks.human(root.sizes.coredump ?? 0))
            disabled: busy
            onClicked: confirmDialog.ask({
                header: Tr.tr("Clear saved crash dumps?"),
                body: Tr.tr("Deletes %1 of stored systemd coredump archives.").arg(Disks.human(root.sizes.coredump ?? 0)),
                confirmLabel: Tr.trCtx("Clear", "button"),
                onConfirm: () => Admin.run("clear-coredumps", [], what, ok => {
                    if (ok)
                        Toaster.toast(Tr.tr("Crash dumps cleared"), "", "bug_report");
                    root.refresh(false);
                })
            })
        }

        RowButton {
            readonly property string what: Tr.tr("Trim system logs")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            icon: "receipt_long"
            text: what
            subtext: busy ? Tr.tr("Trimming…") : Tr.tr("%1 of logs; keeps the last two weeks").arg(Disks.human(root.sizes.journal ?? 0))
            disabled: busy
            onClicked: Admin.run("journal-vacuum", ["2weeks"], what, () => root.refresh(false))
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}
