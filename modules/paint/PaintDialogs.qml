pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import "Tools.js" as Tools

// Paint's dialogs (all inside the window)
Item {
    id: root

    required property var win
    readonly property bool anyOpen: closeDlg.open || enlargeDlg.open || newDlg.open || saveDlg.open || resizeDlg.open || canvasDlg.open || keysDlg.open || replaceDlg.open

    // after a dialog closes: the dialog still open under it, else the canvas
    function nextFocus(): Item {
        for (const d of [replaceDlg, enlargeDlg, closeDlg, saveDlg, newDlg, resizeDlg, canvasDlg, keysDlg])
            if (d.open)
                return d;
        return win.canvasRef;
    }

    function askClose(): void {
        closeDlg.open = true;
    }

    function askEnlarge(path: string, w: real, h: real, at: var): void {
        enlargeDlg.args = {
            path: path,
            w: w,
            h: h,
            at: at
        };
        enlargeDlg.open = true;
    }

    function newPicture(): void {
        newW.text = String(Math.round(win.doc.W));
        newH.text = String(Math.round(win.doc.H));
        newDlg.bg = "#ffffff";
        newDlg.open = true;
    }

    function saveAs(): void {
        win.finishText();
        const p = win.savePath || (win.source ? win.source.replace(/\.[^./]+$/, "") + "-edited.png" : `${Paths.pictures}/Paint/Paint_${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.png`);
        saveDlg.folder = p.slice(0, p.lastIndexOf("/"));
        const file = p.split("/").pop();
        const ext = (file.match(/\.([^.]+)$/)?.[1] ?? "png").toLowerCase();
        saveDlg.format = ext === "jpeg" ? "jpg" : (["png", "jpg", "webp"].includes(ext) ? ext : "png");
        saveName.text = file.replace(/\.[^.]+$/, "");
        saveDlg.open = true;
        Qt.callLater(() => saveName.forceActiveFocus());
    }

    function resize(): void {
        resizeDlg.byPercent = true;
        resizeDlg.keep = true;
        resizeW.text = "100";
        resizeH.text = "100";
        resizeDlg.open = true;
    }

    function canvasSize(): void {
        canvasW.text = String(Math.round(win.doc.W));
        canvasH.text = String(Math.round(win.doc.H));
        canvasDlg.ax = 0.5;
        canvasDlg.ay = 0.5;
        canvasDlg.open = true;
    }

    function shortcuts(): void {
        keysDlg.open = true;
    }

    component Field: StyledTextField {
        Layout.preferredWidth: 110
        verticalPadding: Tokens.padding.small
        floatingPlaceholder: false
        validate: /^\d{1,5}$/
        emptyIsValid: false
        horizontalAlignment: TextInput.AlignHCenter
    }

    component Caption: StyledText {
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }

    component Choice: TextButton {
        type: TextButton.Tonal
        isToggle: true
    }

    // ---- save before closing? ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: closeDlg

        title: Tr.tr("Save changes to “%1”?").arg(root.win.docName)
        icon: "save"

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Your changes will be lost if you don't save them.")
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: closeDlg.open = false
            },
            TextButton {
                type: TextButton.Tonal
                text: Tr.tr("Don't save")
                onClicked: {
                    closeDlg.open = false;
                    root.win.forceClose = true;
                    root.win.discardSession();
                    root.win.close();
                }
            },
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Save")
                onClicked: {
                    closeDlg.open = false;
                    root.win.closeAfterSave = true;
                    root.win.save();
                }
            }
        ]
    }

    // ---- pasted picture bigger than the canvas ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: enlargeDlg

        property var args: null

        title: Tr.tr("The picture is bigger than the canvas")
        icon: "photo_size_select_large"

        StyledText {
            Layout.fillWidth: true
            text: enlargeDlg.args ? Tr.tr("It's %1 × %2, the canvas %3 × %4. Make the canvas big enough for it?").arg(Math.round(enlargeDlg.args.w)).arg(Math.round(enlargeDlg.args.h)).arg(Math.round(root.win.doc.W)).arg(Math.round(root.win.doc.H)) : ""
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Keep the canvas")
                onClicked: {
                    enlargeDlg.open = false;
                    const a = enlargeDlg.args;
                    root.win.placeImage(a.path, a.w, a.h, a.at);
                }
            },
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Enlarge the canvas")
                onClicked: {
                    enlargeDlg.open = false;
                    const a = enlargeDlg.args;
                    root.win.enlargeAndPlace(a.path, a.w, a.h, a.at);
                }
            }
        ]
    }

    // ---- new picture ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: newDlg

        property string bg: "#ffffff"

        title: Tr.tr("New picture")
        icon: "note_add"
        cardWidth: 460

        Caption {
            text: Tr.tr("Size (pixels)")
        }
        RowLayout {
            spacing: Tokens.spacing.small

            Field {
                id: newW

                objectName: "field:newW"
            }
            StyledText {
                text: "×"
            }
            Field {
                id: newH

                objectName: "field:newH"
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: [[1920, 1080], [1280, 720], [2560, 1440], [1080, 1080], [800, 600], [1240, 1754]]

                Choice {
                    required property var modelData

                    checked: newW.text === String(modelData[0]) && newH.text === String(modelData[1])
                    text: modelData[0] === 1240 ? Tr.tr("A4 (150 dpi)") : `${modelData[0]} × ${modelData[1]}`
                    onClicked: {
                        newW.text = String(modelData[0]);
                        newH.text = String(modelData[1]);
                    }
                }
            }
        }
        Caption {
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Background")
        }
        RowLayout {
            spacing: Tokens.spacing.small

            Choice {
                checked: newDlg.bg === "#ffffff"
                text: Tr.tr("White")
                onClicked: newDlg.bg = "#ffffff"
            }
            Choice {
                checked: newDlg.bg === "#00000000"
                text: Tr.tr("Transparent")
                onClicked: newDlg.bg = "#00000000"
            }
            Choice {
                checked: newDlg.bg === root.win.second.toString()
                text: Tr.tr("Second colour")
                onClicked: newDlg.bg = root.win.second.toString()
            }
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: newDlg.open = false
            },
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Create")
                disabled: !newW.valid || !newH.valid || +newW.text < 1 || +newH.text < 1
                onClicked: {
                    newDlg.open = false;
                    const page = {
                        w: Math.min(16000, +newW.text),
                        h: Math.min(16000, +newH.text),
                        bg: newDlg.bg
                    };
                    if (root.win.untouched) {
                        root.win.doc = {
                            W: page.w,
                            H: page.h,
                            bg: page.bg,
                            base: null,
                            items: []
                        };
                        root.win.zoomFit();
                    } else {
                        root.win.app.newPicture(page);
                    }
                }
            }
        ]
    }

    // ---- save as ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: saveDlg

        property string folder
        property string format: "png"
        readonly property string target: `${folder}/${saveName.text}.${format}`

        title: Tr.tr("Save as")
        icon: "save_as"
        cardWidth: 500

        Caption {
            text: Tr.tr("Name")
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: saveName

                objectName: "field:saveName"
                Layout.fillWidth: true
                verticalPadding: Tokens.padding.small
                floatingPlaceholder: false
                validate: /^[^\/]+$/
                emptyIsValid: false
                onAccepted: saveBtn.clicked()
            }
            StyledText {
                text: `.${saveDlg.format}`
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        Caption {
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Folder")
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "folder"
                color: Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                text: Paths.shortenHome(saveDlg.folder)
                elide: Text.ElideMiddle
            }
            TextButton {
                type: TextButton.Tonal
                text: Tr.tr("Change…")
                onClicked: folderDialog.openAt(saveDlg.folder)
            }
        }

        Caption {
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Format")
        }
        RowLayout {
            spacing: Tokens.spacing.small

            Choice {
                checked: saveDlg.format === "png"
                text: "PNG"
                onClicked: saveDlg.format = "png"
            }
            Choice {
                checked: saveDlg.format === "jpg"
                text: "JPEG"
                onClicked: saveDlg.format = "jpg"
            }
            Choice {
                checked: saveDlg.format === "webp"
                text: "WebP"
                onClicked: saveDlg.format = "webp"
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: saveDlg.format === "png" ? Tr.tr("Lossless, keeps transparency.") : saveDlg.format === "jpg" ? Tr.tr("Smaller files; no transparency (filled with white).") : Tr.tr("Small files, keeps transparency.")
            wrapMode: Text.Wrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }
        RowLayout {
            Layout.fillWidth: true
            visible: saveDlg.format !== "png"
            spacing: Tokens.spacing.small

            Caption {
                text: Tr.tr("Quality")
            }
            StyledSlider {
                Layout.fillWidth: true
                implicitHeight: 26
                from: 40
                to: 100
                value: root.win.saveQuality
                onMoved: root.win.saveQuality = Math.round(value)
            }
            Caption {
                Layout.preferredWidth: 36
                text: `${root.win.saveQuality}`
            }
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: saveDlg.open = false
            },
            TextButton {
                id: saveBtn

                type: TextButton.Filled
                text: Tr.tr("Save")
                disabled: !saveName.valid
                onClicked: {
                    if (disabled)
                        return;
                    existsProc.target = saveDlg.target;
                    existsProc.running = true;
                }
            }
        ]
    }

    Process {
        id: existsProc

        property string target

        command: ["test", "-e", target]
        onExited: code => {
            if (code === 0 && target !== root.win.savePath) {
                replaceDlg.open = true;
            } else {
                saveDlg.open = false;
                root.win.saveTo(target);
            }
        }
    }

    PaintDialog {
        focusReturn: root.nextFocus
        id: replaceDlg

        title: Tr.tr("Replace “%1”?").arg(existsProc.target.split("/").pop())
        icon: "warning"

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("A file with this name is already in the folder. Replacing it overwrites it.")
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: replaceDlg.open = false
            },
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Replace")
                onClicked: {
                    replaceDlg.open = false;
                    saveDlg.open = false;
                    root.win.saveTo(existsProc.target);
                }
            }
        ]
    }

    FileDialog {
        id: folderDialog

        folderMode: true
        title: Tr.tr("Choose a folder")
        onAccepted: path => saveDlg.folder = path
    }

    // ---- resize ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: resizeDlg

        property bool byPercent: true
        property bool keep: true
        property bool syncing
        readonly property int outW: byPercent ? Math.round(root.win.doc.W * (+resizeW.text) / 100) : +resizeW.text
        readonly property int outH: byPercent ? Math.round(root.win.doc.H * (+resizeH.text) / 100) : +resizeH.text

        title: Tr.tr("Resize the picture")
        icon: "aspect_ratio"

        RowLayout {
            spacing: Tokens.spacing.small

            Choice {
                checked: resizeDlg.byPercent
                text: Tr.tr("Percent")
                onClicked: {
                    resizeDlg.byPercent = true;
                    resizeW.text = "100";
                    resizeH.text = "100";
                }
            }
            Choice {
                checked: !resizeDlg.byPercent
                text: Tr.tr("Pixels")
                onClicked: {
                    resizeDlg.byPercent = false;
                    resizeW.text = String(Math.round(root.win.doc.W));
                    resizeH.text = String(Math.round(root.win.doc.H));
                }
            }
        }
        RowLayout {
            spacing: Tokens.spacing.small

            Field {
                id: resizeW

                objectName: "field:resizeW"

                onTextChanged: {
                    if (!resizeDlg.keep || resizeDlg.syncing || !valid)
                        return;
                    resizeDlg.syncing = true;
                    resizeH.text = resizeDlg.byPercent ? text : String(Math.round(+text * root.win.doc.H / root.win.doc.W));
                    resizeDlg.syncing = false;
                }
            }
            StyledText {
                text: "×"
            }
            Field {
                id: resizeH

                objectName: "field:resizeH"

                onTextChanged: {
                    if (!resizeDlg.keep || resizeDlg.syncing || !valid)
                        return;
                    resizeDlg.syncing = true;
                    resizeW.text = resizeDlg.byPercent ? text : String(Math.round(+text * root.win.doc.W / root.win.doc.H));
                    resizeDlg.syncing = false;
                }
            }
            StyledText {
                text: resizeDlg.byPercent ? "%" : "px"
                color: Colours.palette.m3onSurfaceVariant
            }
        }
        RowLayout {
            spacing: Tokens.spacing.small

            StyledSwitch {
                checked: resizeDlg.keep
                onToggled: resizeDlg.keep = checked
            }
            StyledText {
                text: Tr.tr("Keep the proportions")
            }
        }
        Caption {
            text: Tr.tr("New size: %1 × %2 px").arg(resizeDlg.outW).arg(resizeDlg.outH)
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: resizeDlg.open = false
            },
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Resize")
                disabled: !resizeW.valid || !resizeH.valid || resizeDlg.outW < 1 || resizeDlg.outH < 1 || resizeDlg.outW > 16000 || resizeDlg.outH > 16000
                onClicked: {
                    resizeDlg.open = false;
                    root.win.scalePicture(resizeDlg.outW, resizeDlg.outH);
                }
            }
        ]
    }

    // ---- canvas size ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: canvasDlg

        property real ax: 0.5
        property real ay: 0.5

        title: Tr.tr("Canvas size")
        icon: "crop_free"

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Adds space around the picture (in the background colour) or trims it. The picture keeps its size.")
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
        }
        RowLayout {
            spacing: Tokens.spacing.small

            Field {
                id: canvasW

                objectName: "field:canvasW"
            }
            StyledText {
                text: "×"
            }
            Field {
                id: canvasH

                objectName: "field:canvasH"
            }
            StyledText {
                text: "px"
                color: Colours.palette.m3onSurfaceVariant
            }
        }
        Caption {
            text: Tr.tr("Keep the picture at")
        }
        Grid {
            columns: 3
            spacing: 4

            Repeater {
                model: 9

                StyledRect {
                    id: cell

                    required property int index
                    readonly property real cx: (index % 3) / 2
                    readonly property real cy: Math.floor(index / 3) / 2
                    readonly property bool on: canvasDlg.ax === cx && canvasDlg.ay === cy

                    objectName: `anchor:${index}`
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: Tokens.rounding.small
                    color: on ? Colours.palette.m3primary : Colours.palette.m3surfaceVariant
                    border.width: on ? 0 : 1
                    border.color: Colours.palette.m3outline

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: cell.on
                        text: "image"
                        color: Colours.palette.m3onPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            canvasDlg.ax = cell.cx;
                            canvasDlg.ay = cell.cy;
                        }
                    }
                }
            }
        }

        buttons: [
            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: canvasDlg.open = false
            },
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Apply")
                disabled: !canvasW.valid || !canvasH.valid || +canvasW.text < 1 || +canvasH.text < 1 || +canvasW.text > 16000 || +canvasH.text > 16000
                onClicked: {
                    canvasDlg.open = false;
                    root.win.resizeCanvas(+canvasW.text, +canvasH.text, canvasDlg.ax, canvasDlg.ay, "");
                }
            }
        ]
    }

    // ---- keyboard shortcuts ----
    PaintDialog {
        focusReturn: root.nextFocus
        id: keysDlg

        title: Tr.tr("Keyboard shortcuts")
        icon: "keyboard"
        cardWidth: 720

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: Tokens.spacing.large
            rowSpacing: 4

            Repeater {
                model: [...Tools.list.map(t => [t.key, Tr.tr(Tools.names[t.id])]), ["Space", Tr.tr("Hold and drag: move the view")], ["Ctrl+V", Tr.tr("Paste")], ["Ctrl+Shift+V", Tr.tr("Paste as a new picture")], ["Ctrl+C / Ctrl+X", Tr.tr("Copy / cut (selection, area or picture)")], ["Ctrl+Shift+C", Tr.tr("Copy the whole picture")], ["Ctrl+Z / Ctrl+Y", Tr.tr("Undo / redo")], ["Del", Tr.tr("Delete the selection / clear the area")], ["Ctrl+D", Tr.tr("Duplicate")], ["Ctrl+A", Tr.tr("Select all")], ["Arrows", Tr.tr("Nudge (Shift: 10 px)")], ["Ctrl+] / [", Tr.tr("Forward / backward")], ["Ctrl+wheel, Ctrl+± ", Tr.tr("Zoom")], ["Ctrl+0 / Ctrl+1", Tr.tr("Fit / 100%")], ["Ctrl+N / O", Tr.tr("New / open")], ["Ctrl+S", Tr.tr("Save")], ["Ctrl+Shift+S", Tr.tr("Save as")], ["Ctrl+R", Tr.tr("Resize the picture")], ["Ctrl+Shift+R", Tr.tr("Canvas size")], ["Ctrl+W", Tr.tr("Close")], ["Enter / Esc", Tr.tr("Apply / cancel crop")]]

                RowLayout {
                    id: keyRow

                    required property var modelData

                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledRect {
                        implicitWidth: Math.max(30, keyText.implicitWidth + Tokens.padding.small * 2)
                        implicitHeight: keyText.implicitHeight + 6
                        radius: Tokens.rounding.extraSmall
                        color: Colours.palette.m3surfaceContainerHighest

                        StyledText {
                            id: keyText

                            anchors.centerIn: parent
                            text: keyRow.modelData[0]
                            font: Tokens.font.label.medium
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: keyRow.modelData[1]
                        elide: Text.ElideRight
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        buttons: [
            TextButton {
                type: TextButton.Filled
                text: Tr.tr("Close")
                onClicked: keysDlg.open = false
            }
        ]
    }
}
