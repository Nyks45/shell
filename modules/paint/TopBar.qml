pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// File, clipboard, history, picture and zoom actions along the top
Item {
    id: root

    required property var win

    implicitHeight: bar.implicitHeight + Tokens.padding.small * 2

    component Sep: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 24
        color: Colours.palette.m3outlineVariant
    }

    StyledRect {
        id: bar

        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        anchors.bottomMargin: 0
        implicitHeight: row.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainer

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.extraSmall

            PaintButton {
                icon: "note_add"
                tip: Tr.tr("New picture")
                keys: "Ctrl+N"
                onClicked: root.win.dialogsRef.newPicture()
            }
            PaintButton {
                icon: "folder_open"
                tip: Tr.tr("Open")
                keys: "Ctrl+O"
                onClicked: root.win.openDialogRef.open()
            }
            PaintButton {
                icon: "save"
                tip: Tr.tr("Save")
                keys: "Ctrl+S"
                onClicked: root.win.save()
            }
            PaintButton {
                icon: "save_as"
                tip: Tr.tr("Save as…")
                keys: "Ctrl+Shift+S"
                onClicked: root.win.dialogsRef.saveAs()
            }

            Sep {}

            PaintButton {
                icon: "content_copy"
                tip: root.win.area ? Tr.tr("Copy the area") : root.win.selected.length ? Tr.tr("Copy the selection") : Tr.tr("Copy the picture")
                keys: "Ctrl+C"
                onClicked: root.win.copy()
            }
            PaintButton {
                icon: "content_cut"
                tip: Tr.tr("Cut")
                keys: "Ctrl+X"
                disabled: !root.win.area && root.win.selected.length === 0
                onClicked: root.win.cut()
            }
            PaintButton {
                icon: "content_paste"
                tip: Tr.tr("Paste")
                keys: "Ctrl+V"
                onClicked: root.win.paste()
            }

            Sep {}

            PaintButton {
                icon: "undo"
                tip: Tr.tr("Undo")
                keys: "Ctrl+Z"
                disabled: root.win.history.length === 0 && !root.win.editing
                onClicked: root.win.undo()
            }
            PaintButton {
                icon: "redo"
                tip: Tr.tr("Redo")
                keys: "Ctrl+Shift+Z"
                disabled: root.win.future.length === 0
                onClicked: root.win.redo()
            }

            Sep {}

            IconTextButton {
                id: imageBtn

                objectName: "top:picture"
                type: IconTextButton.Text
                icon: "photo_size_select_large"
                text: Tr.tr("Picture")
                onClicked: imageMenu.expanded = !imageMenu.expanded
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: root.width * 0.25
                text: root.win.docName
                elide: Text.ElideMiddle
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            Item {
                Layout.fillWidth: true
            }

            PaintButton {
                objectName: "top:zoom_out"
                icon: "zoom_out"
                tip: Tr.tr("Zoom out")
                keys: "Ctrl+−"
                onClicked: root.win.zoomStep(-1)
            }

            TextButton {
                id: zoomBtn

                objectName: "top:zoom"
                Layout.preferredWidth: 72
                type: TextButton.Text
                text: root.win.fitMode ? Tr.tr("Fit") : `${Math.round(root.win.zoom * 100)}%`
                onClicked: zoomMenu.expanded = !zoomMenu.expanded
            }

            PaintButton {
                objectName: "top:zoom_in"
                icon: "zoom_in"
                tip: Tr.tr("Zoom in")
                keys: "Ctrl++"
                onClicked: root.win.zoomStep(1)
            }

            Sep {}

            PaintButton {
                icon: "keyboard"
                tip: Tr.tr("Keyboard shortcuts")
                keys: "F1"
                onClicked: root.win.dialogsRef.shortcuts()
            }
        }
    }

    Menu {
        id: imageMenu

        parent: root.win.contentItem
        attachTo: imageBtn
        attachSideX: Menu.Left
        thisSideX: Menu.Left
        active: null
        items: [miResize, miCanvas, miCropArea, miRotL, miRotR, miFlipH, miFlipV]
    }

    MenuItem {
        id: miResize

        text: Tr.tr("Resize…  (Ctrl+R)")
        icon: "aspect_ratio"
        onClicked: root.win.dialogsRef.resize()
    }
    MenuItem {
        id: miCanvas

        text: Tr.tr("Canvas size…  (Ctrl+Shift+R)")
        icon: "crop_free"
        onClicked: root.win.dialogsRef.canvasSize()
    }
    MenuItem {
        id: miCropArea

        text: root.win.area ? Tr.tr("Crop to the area") : Tr.tr("Crop…")
        icon: "crop"
        onClicked: {
            if (root.win.area) {
                root.win.crop(root.win.area);
            } else {
                root.win.setTool("crop");
            }
        }
    }
    MenuItem {
        id: miRotL

        text: Tr.tr("Rotate left")
        icon: "rotate_left"
        onClicked: root.win.bake(3, false, false)
    }
    MenuItem {
        id: miRotR

        text: Tr.tr("Rotate right")
        icon: "rotate_right"
        onClicked: root.win.bake(1, false, false)
    }
    MenuItem {
        id: miFlipH

        text: Tr.tr("Flip horizontally")
        icon: "flip"
        onClicked: root.win.bake(0, true, false)
    }
    MenuItem {
        id: miFlipV

        text: Tr.tr("Flip vertically")
        icon: "flip"
        onClicked: root.win.bake(0, false, true)
    }

    Menu {
        id: zoomMenu

        parent: root.win.contentItem
        attachTo: zoomBtn
        active: null
        items: [zFit, z50, z100, z200, z400, z800]
    }

    MenuItem {
        id: zFit

        text: Tr.tr("Fit to window  (Ctrl+0)")
        icon: "fit_screen"
        onClicked: root.win.zoomFit()
    }
    MenuItem {
        id: z50

        text: "50%"
        onClicked: root.win.zoomTo(0.5)
    }
    MenuItem {
        id: z100

        text: Tr.tr("100%  (Ctrl+1)")
        onClicked: root.win.zoomTo(1)
    }
    MenuItem {
        id: z200

        text: "200%"
        onClicked: root.win.zoomTo(2)
    }
    MenuItem {
        id: z400

        text: "400%"
        onClicked: root.win.zoomTo(4)
    }
    MenuItem {
        id: z800

        text: "800%"
        onClicked: root.win.zoomTo(8)
    }
}
