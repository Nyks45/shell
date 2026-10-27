pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

// Icons for what's in the desktop folder, like Windows': a grid filled top to
// bottom from the top left. Double-click opens, right-click for a menu, drag
// to move one (it's remembered; dropped on another, the two swap).
Item {
    id: root

    readonly property real cellW: 112
    readonly property real cellH: 108
    readonly property real iconSize: 52
    readonly property int rows: Math.max(1, Math.floor(height / cellH))
    readonly property int cols: Math.max(1, Math.floor(width / cellW))

    property string selected

    // The Trash, as an icon of its own (first, like Windows' Recycle Bin)
    readonly property string trashDir: `${Quickshell.env("XDG_DATA_HOME") || `${Quickshell.env("HOME")}/.local/share`}/Trash/files`
    readonly property bool trashFull: trashFiles.entries.length > 0
    readonly property var trashEntry: ({
            name: "::trash",
            path: "trash:///",
            isDir: true,
            isImage: false,
            isTrash: true,
            suffix: "",
            baseName: "Trash",
            mimeType: ""
        })

    // File name -> { col, row }: where the user put it if that cell is free and
    // on screen, else the next free cell, column by column (folders first)
    readonly property var placed: {
        const out = {};
        const taken = new Set();
        const key = (c, r) => c * 10000 + r;
        const entries = [];
        for (let i = 0; i < files.entries.length; i++)
            entries.push(files.entries[i]);
        entries.sort((a, b) => (b.isDir - a.isDir) || a.name.localeCompare(b.name));
        entries.unshift(trashEntry);
        const rest = [];
        for (const e of entries) {
            const p = DesktopFiles.positions[e.name];
            if (p && p.col < cols && p.row < rows && !taken.has(key(p.col, p.row))) {
                out[e.name] = p;
                taken.add(key(p.col, p.row));
            } else {
                rest.push(e);
            }
        }
        let c = 0, r = 0;
        for (const e of rest) {
            while (taken.has(key(c, r))) {
                if (++r >= rows) {
                    r = 0;
                    c++;
                }
            }
            out[e.name] = {
                col: c,
                row: r
            };
            taken.add(key(c, r));
        }
        return out;
    }

    // Move `name` to a cell; whatever was there takes its old one
    function moveTo(name: string, col: int, row: int): void {
        const from = placed[name];
        const other = Object.keys(placed).find(n => n !== name && placed[n].col === col && placed[n].row === row);
        if (other && from)
            DesktopFiles.setPosition(other, from.col, from.row);
        DesktopFiles.setPosition(name, col, row);
    }

    // Kinds every icon theme draws (text, pictures, PDFs, archives...): the
    // rest get the icon of the app that opens them, like on Windows (themes
    // rarely have one for e.g. application/x-remmina, and Qt then quietly
    // falls back to a generic one)
    function themeDraws(mime: string): bool {
        return /^(text|image|video|audio|font|inode)\//.test(mime) || /^application\/(pdf|zip|gzip|x-(compressed-)?tar|x-7z-compressed|vnd\.rar|x-rar|json|xml|x-iso9660-image|x-executable|x-shellscript|vnd\.oasis|vnd\.openxmlformats|msword|vnd\.ms-)/.test(mime);
    }

    // A file's icon: the opening app's for types themes don't draw (`handler`,
    // once known), else its type's (text-plain), else its kind's
    function iconFor(entry: var, handler: string): string {
        if (entry.isDir)
            return Quickshell.iconPath("folder");
        const mime = entry.mimeType || "application/octet-stream";
        if (handler && !themeDraws(mime))
            return Quickshell.iconPath(handler, "application-x-executable");
        const own = Quickshell.iconPath(mime.replace("/", "-"), true);
        if (own)
            return own;
        const major = mime.split("/")[0];
        const generic = {
            image: "image-x-generic",
            video: "video-x-generic",
            audio: "audio-x-generic",
            text: "text-x-generic"
        }[major] ?? "application-x-generic";
        return Quickshell.iconPath(generic, true) || Quickshell.iconPath("text-x-generic");
    }

    // The selected file (not the Trash), or null
    function selectedEntry(): var {
        for (let i = 0; i < files.entries.length; i++)
            if (files.entries[i].name === selected)
                return files.entries[i];
        return null;
    }

    function openSelected(): void {
        const e = selectedEntry();
        if (selected === trashEntry.name)
            DesktopFiles.open(trashEntry.path, true);
        else if (e)
            DesktopFiles.open(e.path, e.isDir);
    }

    function openMenu(items: list<MenuItem>, x: real, y: real): void {
        menuAnchor.x = x;
        menuAnchor.y = y;
        menu.items = items;
        menu.expanded = true;
    }

    // Keyboard, once the desktop was clicked: Delete trashes the selected
    // icon, Ctrl+Z brings it back (within 5 minutes), Enter opens it, Escape
    // deselects
    focus: true
    Keys.onDeletePressed: {
        const e = selectedEntry();
        if (!e)
            return;
        DesktopFiles.trash(e.path);
        selected = "";
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            DesktopFiles.undoTrash();
            event.accepted = true;
        }
    }
    Keys.onReturnPressed: openSelected()
    Keys.onEnterPressed: openSelected()
    Keys.onEscapePressed: selected = ""

    FileSystemModel {
        id: files

        path: DesktopFiles.dir
        watchChanges: true
    }

    FileSystemModel {
        id: trashFiles

        path: root.trashDir
        watchChanges: true
        showHidden: true
    }

    // Empty desktop: clicks clear the selection, right-click for a menu
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            root.forceActiveFocus();
            root.selected = "";
            if (event.button === Qt.RightButton)
                root.openMenu([openFolderItem, settingsItem], event.x, event.y);
        }
    }

    DesktopIcon {
        modelData: root.trashEntry
    }

    Repeater {
        model: files.entries

        DesktopIcon {}
    }

    Item {
        id: menuAnchor

        width: 1
        height: 1
    }

    Menu {
        id: menu

        property var target: null

        attachTo: menuAnchor
        attachSideX: Menu.Left
        attachSideY: Menu.Top
        thisSideX: Menu.Left
        thisSideY: Menu.Top
        active: null
    }

    MenuItem {
        id: openItem

        text: qsTr("Open")
        icon: "open_in_new"
        onClicked: DesktopFiles.open(menu.target.path, menu.target.isDir)
    }

    MenuItem {
        id: trashItem

        text: qsTr("Move to Trash")
        icon: "delete"
        onClicked: DesktopFiles.trash(menu.target.path)
    }

    MenuItem {
        id: emptyTrashItem

        text: qsTr("Empty Trash…")
        icon: "delete_forever"
        onClicked: Qt.callLater(() => root.openMenu([confirmEmptyItem, cancelItem], menuAnchor.x, menuAnchor.y))
    }

    MenuItem {
        id: confirmEmptyItem

        text: qsTr("Delete everything in the Trash for good")
        icon: "delete_forever"
        onClicked: DesktopFiles.emptyTrash()
    }

    MenuItem {
        id: cancelItem

        text: qsTr("Cancel")
        icon: "close"
    }

    MenuItem {
        id: openFolderItem

        text: qsTr("Open the Desktop folder")
        icon: "folder_open"
        onClicked: Quickshell.execDetached([...GlobalConfig.general.apps.explorer, DesktopFiles.dir])
    }

    MenuItem {
        id: settingsItem

        text: qsTr("Settings")
        icon: "settings"
        onClicked: WindowFactory.create()
    }

    component DesktopIcon: Item {
        id: icon

        required property var modelData
        readonly property bool isTrash: modelData.isTrash ?? false
        readonly property var cell: root.placed[modelData.name] ?? {
            col: 0,
            row: 0
        }
        readonly property bool isApp: modelData.suffix === "desktop"
        readonly property bool isSelected: root.selected === modelData.name
        property bool dragging
        // From the desktop file, for apps
        property string appName
        property string appIcon
        // Icon of the app that opens this file, for types without their own
        property string handlerIcon

        x: cell.col * root.cellW
        y: cell.row * root.cellH
        z: dragging ? 2 : 1
        width: root.cellW
        height: root.cellH

        Behavior on x {
            enabled: !icon.dragging

            Anim {}
        }
        Behavior on y {
            enabled: !icon.dragging

            Anim {}
        }

        StyledRect {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            radius: Tokens.rounding.medium
            color: Qt.alpha(Colours.palette.m3primary, icon.isSelected ? 0.32 : mouse.containsMouse ? 0.14 : 0)

            Behavior on color {
                CAnim {}
            }
        }

        // Images show themselves (small); the rest their app's or type's icon
        Loader {
            id: picture

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.medium
            width: root.iconSize
            height: root.iconSize

            sourceComponent: icon.modelData.isImage ? thumbnail : themed
        }

        Component {
            id: thumbnail

            ClippingRectangle {
                radius: Tokens.rounding.small
                color: "transparent"

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: root.iconSize * 2
                    sourceSize.height: root.iconSize * 2
                    source: `file://${icon.modelData.path}`
                }
            }
        }

        Component {
            id: themed

            IconImage {
                asynchronous: true
                implicitSize: root.iconSize
                source: {
                    if (icon.isTrash)
                        return Quickshell.iconPath(root.trashFull ? "user-trash-full" : "user-trash", "user-trash");
                    if (!icon.isApp)
                        return root.iconFor(icon.modelData, icon.handlerIcon);
                    if (icon.appIcon.startsWith("/"))
                        return `file://${icon.appIcon}`;
                    return Quickshell.iconPath(icon.appIcon, "application-x-executable");
                }
            }
        }

        StyledText {
            id: label

            anchors.top: picture.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Tokens.padding.small * 2
            horizontalAlignment: Text.AlignHCenter
            text: icon.isTrash ? qsTr("Trash") : icon.isApp ? (icon.appName || icon.modelData.baseName) : icon.modelData.name
            color: "white"
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
            maximumLineCount: icon.isSelected ? 4 : 2
            elide: Text.ElideRight

            // Readable on any wallpaper
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.9)
                shadowBlur: 0.5
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
            }
        }

        MouseArea {
            id: mouse

            property point pressPos

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: icon.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: pressedButtons & Qt.LeftButton ? icon : undefined
            drag.threshold: 8

            onPressed: event => {
                root.forceActiveFocus();
                root.selected = icon.modelData.name;
                pressPos = Qt.point(event.x, event.y);
            }
            onDoubleClicked: event => {
                if (event.button === Qt.LeftButton)
                    DesktopFiles.open(icon.modelData.path, icon.modelData.isDir);
            }
            onClicked: event => {
                if (event.button !== Qt.RightButton)
                    return;
                menu.target = icon.modelData;
                const p = mapToItem(root, event.x, event.y);
                if (icon.isTrash)
                    root.openMenu(root.trashFull ? [openItem, emptyTrashItem] : [openItem], p.x, p.y);
                else
                    root.openMenu([openItem, trashItem], p.x, p.y);
            }
            drag.onActiveChanged: {
                if (drag.active) {
                    icon.dragging = true;
                    return;
                }
                // Dropped: onto the cell under its middle
                const col = Math.max(0, Math.min(root.cols - 1, Math.round(icon.x / root.cellW)));
                const row = Math.max(0, Math.min(root.rows - 1, Math.round(icon.y / root.cellH)));
                root.moveTo(icon.modelData.name, col, row);
                icon.dragging = false;
                icon.x = Qt.binding(() => icon.cell.col * root.cellW);
                icon.y = Qt.binding(() => icon.cell.row * root.cellH);
            }
        }

        // The app that opens it (for a type the icon theme has no icon for)
        Process {
            running: !icon.isApp && !icon.isTrash && !icon.modelData.isDir && !icon.modelData.isImage && !!icon.modelData.mimeType && !root.themeDraws(icon.modelData.mimeType)
            // Its Icon= line (the handler can be a hidden entry, e.g. Remmina's
            // file opener, which the app list leaves out)
            command: ["sh", "-c", "f=$(xdg-mime query default \"$1\"); [ -n \"$f\" ] || exit; for d in \"${XDG_DATA_HOME:-$HOME/.local/share}/applications\" /usr/local/share/applications /usr/share/applications; do [ -f \"$d/$f\" ] && { sed -n 's/^Icon=//p' \"$d/$f\" | head -1; exit; }; done", "sh", icon.modelData.mimeType ?? ""]
            stdout: StdioCollector {
                onStreamFinished: icon.handlerIcon = text.trim()
            }
        }

        // Name and icon of a launcher
        FileView {
            path: icon.isApp ? icon.modelData.path : ""
            printErrors: false
            onLoaded: {
                const main = text().split(/^\[(?!Desktop Entry\])/m)[0];
                const get = k => main.match(new RegExp(`^${k}=(.*)$`, "m"))?.[1]?.trim() ?? "";
                icon.appName = get("Name");
                icon.appIcon = get("Icon");
            }
        }
    }
}
