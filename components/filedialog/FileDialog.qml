pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

LazyLoader {
    id: loader

    property list<string> cwd: ["Home"]
    property bool folderMode: false
    property bool showHidden: false
    property string filterLabel: Tr.tr("All files")
    property list<string> filters: ["*"]
    property string title: folderMode ? Tr.tr("Select a folder") : Tr.tr("Select a file")

    signal accepted(path: string)
    signal rejected

    function open(): void {
        activeAsync = true;
    }

    function openAt(path: string): void {
        let p = (path || "").trim().replace(/^~(?=\/|$)/, Paths.home);
        if (p.length > 1)
            p = p.replace(/\/+$/, "");
        if (!p || p === Paths.home) {
            cwd = ["Home"];
        } else if (p.startsWith(Paths.home + "/")) {
            cwd = ["Home", ...p.slice(Paths.home.length + 1).split("/").filter(Boolean)];
        } else if (p === "/") {
            cwd = ["/"];
        } else if (p.startsWith("/")) {
            cwd = ["/", ...p.slice(1).split("/").filter(Boolean)];
        } else {
            cwd = ["Home"];
        }
        open();
    }

    function close(): void {
        rejected();
    }

    onAccepted: activeAsync = false
    onRejected: activeAsync = false

    FloatingWindow {
        id: root

        property list<string> cwd: loader.cwd
        property bool folderMode: loader.folderMode
        property bool showHidden: loader.showHidden
        property string filterLabel: loader.filterLabel
        property list<string> filters: loader.filters

        readonly property string currentPath: {
            if (cwd.length === 0)
                return Paths.home;
            if (cwd[0] === "Home")
                return cwd.length === 1 ? Paths.home : `${Paths.home}/${cwd.slice(1).join("/")}`;
            if (cwd[0] === "/")
                return "/" + cwd.slice(1).join("/");
            return cwd.join("/");
        }

        readonly property string selectedPath: {
            const file = folderContents.currentItem?.modelData;
            if (folderMode)
                return file?.isDir ? file.path : currentPath;
            return file?.path ?? "";
        }

        readonly property bool selectionValid: {
            if (folderMode)
                return selectedPath.length > 0;
            const file = folderContents.currentItem?.modelData;
            return (file && !file.isDir && (filters.includes("*") || filters.some(filter => filter.toLowerCase() === file.suffix.toLowerCase()))) ?? false;
        }

        function accepted(path: string): void {
            loader.accepted(path);
        }

        function rejected(): void {
            loader.rejected();
        }

        implicitWidth: 1000
        implicitHeight: 600
        minimumSize.width: 400
        minimumSize.height: 300
        color: Colours.tPalette.m3surface
        surfaceFormat.opaque: false
        title: loader.title

        onVisibleChanged: {
            if (!visible)
                rejected();
        }

        RowLayout {
            anchors.fill: parent

            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                dialog: root
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                HeaderBar {
                    Layout.fillWidth: true
                    dialog: root
                }

                FolderContents {
                    id: folderContents

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    dialog: root
                }

                DialogButtons {
                    Layout.fillWidth: true
                    dialog: root
                    folder: folderContents
                }
            }
        }

        Behavior on color {
            CAnim {}
        }
    }
}
