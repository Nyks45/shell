pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// The settings of the current tool (or of the selected objects), along the bottom
Item {
    id: root

    required property var win
    readonly property string k: win.propsKind
    readonly property var sel: win.selItem
    readonly property bool hasSel: win.tool === "select" && win.selected.length > 0
    readonly property bool showColour: ["pen", "highlighter", "line", "arrow", "rect", "ellipse", "text", "callout", "step", "multi"].includes(k)
    readonly property bool showThickness: ["pen", "highlighter", "line", "arrow", "rect", "ellipse", "step", "eraser", "multi"].includes(k)
    readonly property bool showOpacity: ["pen", "line", "arrow", "rect", "ellipse", "image"].includes(k)
    readonly property bool showDash: ["line", "arrow", "rect", "ellipse"].includes(k)
    readonly property bool showFont: k === "text" || k === "callout"
    property string pickerFor: "colour"
    // short of room: the swatches fold into the palette button (the picker has them)
    readonly property int swatchCount: win.swatches.length + (win.app.prefs.recent ?? []).length
    readonly property real swatchesWidth: swatchCount * 24 + swatchCount * Tokens.spacing.small
    // short of room: decided just after layout (a binding would loop through the row's width)
    property bool compact

    function updateCompact(): void {
        const rest = row.implicitWidth - (swatchRow.visible ? swatchesWidth : 0);
        // (sliders and the swap button shrink too: about 110 px)
        compact = rest + (showColour ? swatchesWidth : 0) + (compact ? 110 : 0) + Tokens.padding.medium * 2 > width - Tokens.padding.small * 2;
    }

    onWidthChanged: Qt.callLater(updateCompact)
    onShowColourChanged: Qt.callLater(updateCompact)
    onKChanged: Qt.callLater(updateCompact)
    onSwatchCountChanged: Qt.callLater(updateCompact)

    Connections {
        target: row

        function onImplicitWidthChanged(): void {
            Qt.callLater(root.updateCompact);
        }
    }

    // the shown values: the selected object's own, else the tool's
    readonly property real vThickness: {
        if (sel && g2.isPointsKind(sel.kind))
            return sel.kind === "highlighter" ? Math.round(sel.width / 4) : sel.width;
        if (sel && sel.kind === "step")
            return Math.round((sel.size - 12) / 3);
        return win.thickness;
    }
    readonly property real vOpacity: sel && sel.opacity !== undefined ? sel.opacity : win.penOpacity
    readonly property string vDash: sel?.dash ?? win.dash
    readonly property string vHead: sel?.head ?? win.head
    readonly property bool vBoth: sel?.both ?? win.both
    readonly property string vFill: sel?.fill ?? win.fill
    readonly property real vRadius: sel?.radius ?? win.radius
    readonly property real vFont: (sel && (sel.kind === "text" || sel.kind === "callout")) ? sel.size : win.fontSize
    readonly property string vFamily: sel?.family ?? win.family
    readonly property bool vBold: sel?.kind === "text" ? !!sel.bold : win.bold
    readonly property bool vItalic: sel?.kind === "text" ? !!sel.italic : win.italic
    readonly property bool vBox: sel?.kind === "text" ? !!sel.box : win.box
    readonly property bool vOutline: sel?.kind === "text" ? !!sel.outline : win.outline
    readonly property string vMode: sel?.mode ?? win.redactMode
    readonly property real vStrength: sel?.strength ?? win.redactStrength
    readonly property string vShape: sel?.shape ?? win.spotShape
    readonly property real vDim: sel?.dim ?? win.spotDim
    readonly property real vZoom: sel?.zoom ?? win.magZoom
    readonly property color vColour: sel?.colour ? Qt.color(sel.colour) : win.colour

    implicitHeight: bar.implicitHeight + Tokens.padding.small * 2

    QtObject {
        id: g2

        function isPointsKind(k: string): bool {
            return ["pen", "highlighter", "line", "arrow", "rect", "ellipse"].includes(k);
        }
    }

    component Sep: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 24
        color: Colours.palette.m3outlineVariant
    }

    component Label: StyledText {
        Layout.alignment: Qt.AlignVCenter
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }

    component Toggle: PaintButton {
        Layout.alignment: Qt.AlignVCenter
        type: IconButton.Tonal
        isToggle: true
        inactiveColour: "transparent"
    }

    component Slider: StyledSlider {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: root.compact ? 64 : 96
        implicitHeight: 26
    }

    component Swatch: Rectangle {
        id: sw

        property color c
        property bool chosen

        signal picked(right: bool)

        objectName: `swatch:${c}`
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 24
        implicitHeight: 24
        radius: 12
        color: c
        border.width: chosen ? 3 : 1
        border.color: chosen ? Colours.palette.m3primary : Colours.palette.m3outline

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => sw.picked(m.button === Qt.RightButton)
        }
    }

    StyledRect {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.small
        width: Math.min(row.implicitWidth + Tokens.padding.medium * 2, root.width - Tokens.padding.small * 2)
        implicitHeight: 48
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainer

        Flickable {
            id: propsFlick

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            contentWidth: row.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width
            flickableDirection: Flickable.HorizontalFlick

            RowLayout {
                id: row

                height: parent.height
                spacing: Tokens.spacing.small

                // ---- what the tool does, when it has no settings ----
                Label {
                    visible: ["select", "eyedropper", "hand"].includes(root.k) && !root.hasSel || root.k === "area" && !root.win.area
                    text: root.k === "eyedropper" ? Tr.tr("Click the picture to take a colour (right button: second colour)") : root.k === "area" ? Tr.tr("Drag to select part of the picture") : Tr.tr("Click an object to select it; drag around several")
                }

                // ---- selection actions ----
                PaintButton {
                    visible: root.hasSel
                    icon: "control_point_duplicate"
                    tip: Tr.tr("Duplicate")
                    keys: "Ctrl+D"
                    onClicked: root.win.duplicate()
                }
                PaintButton {
                    visible: root.hasSel
                    icon: "flip_to_front"
                    tip: Tr.tr("Bring to front")
                    keys: "Ctrl+Shift+]"
                    onClicked: root.win.reorder("front")
                }
                PaintButton {
                    visible: root.hasSel
                    icon: "flip_to_back"
                    tip: Tr.tr("Send to back")
                    keys: "Ctrl+Shift+["
                    onClicked: root.win.reorder("back")
                }
                PaintButton {
                    visible: root.hasSel
                    icon: "delete"
                    tip: Tr.tr("Delete")
                    keys: "Del"
                    onClicked: root.win.removeIds(root.win.selected)
                }
                Sep {
                    visible: root.hasSel && (root.showColour || root.showOpacity || root.showFont || ["redact", "spotlight", "magnifier"].includes(root.k))
                }

                // ---- area actions ----
                Label {
                    visible: root.k === "area" && !!root.win.area
                    text: root.win.area ? `${Math.round(root.win.area.w)} × ${Math.round(root.win.area.h)}` : ""
                }
                TextButton {
                    visible: root.k === "area" && !!root.win.area
                    type: TextButton.Tonal
                    text: Tr.tr("Copy")
                    onClicked: root.win.copy()
                }
                TextButton {
                    visible: root.k === "area" && !!root.win.area
                    type: TextButton.Tonal
                    text: Tr.tr("Cut")
                    onClicked: root.win.cut()
                }
                TextButton {
                    visible: root.k === "area" && !!root.win.area
                    type: TextButton.Tonal
                    text: Tr.tr("Clear")
                    onClicked: root.win.eraseArea()
                }
                TextButton {
                    visible: root.k === "area" && !!root.win.area
                    type: TextButton.Tonal
                    text: Tr.tr("Crop to it")
                    onClicked: root.win.crop(root.win.area)
                }

                // ---- crop ----
                Repeater {
                    model: root.k === "crop" ? [
                        {
                            t: Tr.tr("Free"),
                            r: 0
                        },
                        {
                            t: Tr.tr("Original"),
                            r: -1
                        },
                        {
                            t: "1:1",
                            r: 1
                        },
                        {
                            t: "4:3",
                            r: 4 / 3
                        },
                        {
                            t: "16:9",
                            r: 16 / 9
                        },
                        {
                            t: "3:2",
                            r: 3 / 2
                        }
                    ] : []

                    TextButton {
                        required property var modelData

                        readonly property real ratio: modelData.r === -1 ? root.win.doc.W / root.win.doc.H : modelData.r

                        Layout.alignment: Qt.AlignVCenter
                        type: TextButton.Tonal
                        isToggle: true
                        checked: Math.abs(root.win.cropRatio - ratio) < 0.001
                        text: modelData.t
                        onClicked: {
                            root.win.cropRatio = ratio;
                            if (ratio > 0 && root.win.cropRect) {
                                // the biggest frame of that shape, centred on the current one
                                const W = root.win.doc.W, H = root.win.doc.H;
                                let w = W, h = W / ratio;
                                if (h > H) {
                                    h = H;
                                    w = H * ratio;
                                }
                                root.win.cropRect = {
                                    x: (W - w) / 2,
                                    y: (H - h) / 2,
                                    w: w,
                                    h: h
                                };
                            }
                        }
                    }
                }
                Label {
                    visible: root.k === "crop" && !!root.win.cropRect
                    Layout.preferredWidth: 96
                    horizontalAlignment: Text.AlignHCenter
                    text: root.win.cropRect ? `${Math.round(root.win.cropRect.w)} × ${Math.round(root.win.cropRect.h)}` : ""
                }
                TextButton {
                    visible: root.k === "crop"
                    type: TextButton.Text
                    text: Tr.tr("Cancel")
                    onClicked: root.win.setTool("select")
                }
                TextButton {
                    visible: root.k === "crop"
                    type: TextButton.Filled
                    text: Tr.tr("Apply")
                    onClicked: {
                        root.win.crop(root.win.cropRect);
                        root.win.setTool("select");
                    }
                }

                // ---- colours ----
                Item {
                    visible: root.showColour
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 40
                    implicitHeight: 34

                    // second colour behind, main colour in front (as in Paint)
                    Rectangle {
                        id: secondChip

                        x: 14
                        y: 10
                        width: 24
                        height: 24
                        radius: 6
                        color: root.win.second
                        border.width: 1
                        border.color: Colours.palette.m3outline

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPicker("second", secondChip)
                        }
                    }
                    Rectangle {
                        id: mainChip

                        width: 26
                        height: 26
                        radius: 7
                        color: root.vColour
                        border.width: 2
                        border.color: Colours.palette.m3surfaceContainer

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            radius: 8
                            color: "transparent"
                            border.width: 1
                            border.color: Colours.palette.m3outline
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPicker("colour", mainChip)
                        }
                    }
                }

                PaintButton {
                    visible: root.showColour && !root.compact
                    icon: "swap_horiz"
                    tip: Tr.tr("Swap the colours")
                    onClicked: {
                        // (copies: a colour read from a property follows it)
                        const a = root.win.colour.toString(), b = root.win.second.toString();
                        root.win.setProp("colour", Qt.color(b));
                        root.win.setProp("second", Qt.color(a));
                    }
                }

                RowLayout {
                    id: swatchRow

                    visible: root.showColour && !root.compact
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.showColour ? root.win.swatches : []

                        Swatch {
                            required property var modelData

                            c: modelData
                            chosen: Qt.colorEqual(root.vColour, modelData)
                            onPicked: right => root.win.setProp(right ? "second" : "colour", Qt.color(modelData))
                        }
                    }

                    Repeater {
                        model: root.showColour ? (root.win.app.prefs.recent ?? []) : []

                        Swatch {
                            required property var modelData

                            c: modelData
                            chosen: Qt.colorEqual(root.vColour, modelData)
                            onPicked: right => root.win.setProp(right ? "second" : "colour", Qt.color(modelData))
                        }
                    }
                }

                PaintButton {
                    id: moreColours

                    visible: root.showColour
                    icon: "palette"
                    tip: Tr.tr("More colours")
                    onClicked: root.openPicker("colour", moreColours)
                }
                PaintButton {
                    visible: root.showColour
                    icon: "colorize"
                    tip: Tr.tr("Pick a colour from the picture")
                    keys: "I"
                    onClicked: root.win.setTool("eyedropper")
                }

                Sep {
                    visible: root.showColour && (root.showThickness || root.showOpacity || root.showFont)
                }

                // ---- size and opacity ----
                MaterialIcon {
                    visible: root.showThickness
                    Layout.alignment: Qt.AlignVCenter
                    text: "line_weight"
                    color: Colours.palette.m3onSurfaceVariant
                }
                Slider {
                    visible: root.showThickness
                    from: 1
                    to: 48
                    value: root.vThickness
                    onMoved: root.win.setProp("thickness", Math.round(value))
                }
                Label {
                    visible: root.showThickness
                    Layout.preferredWidth: 40
                    text: `${Math.round(root.vThickness)} px`
                }

                MaterialIcon {
                    visible: root.showOpacity
                    Layout.alignment: Qt.AlignVCenter
                    text: "opacity"
                    color: Colours.palette.m3onSurfaceVariant
                }
                Slider {
                    visible: root.showOpacity
                    from: 0.1
                    to: 1
                    value: root.vOpacity
                    onMoved: root.win.setProp("penOpacity", Math.round(value * 100) / 100)
                }
                Label {
                    visible: root.showOpacity
                    Layout.preferredWidth: 38
                    text: `${Math.round(root.vOpacity * 100)}%`
                }

                // ---- pen ----
                Toggle {
                    visible: root.k === "pen"
                    icon: "gesture"
                    tip: Tr.tr("Smooth strokes")
                    checked: root.win.smoothing
                    onClicked: root.win.setProp("smoothing", !root.win.smoothing)
                }

                // ---- line style ----
                Sep {
                    visible: root.showDash
                }
                Repeater {
                    model: root.showDash ? [
                        {
                            v: "solid",
                            i: "horizontal_rule",
                            t: Tr.tr("Solid line")
                        },
                        {
                            v: "dash",
                            i: "line_style",
                            t: Tr.tr("Dashed line")
                        },
                        {
                            v: "dot",
                            i: "more_horiz",
                            t: Tr.tr("Dotted line")
                        }
                    ] : []

                    Toggle {
                        required property var modelData

                        icon: modelData.i
                        tip: modelData.t
                        checked: root.vDash === modelData.v
                        onClicked: root.win.setProp("dash", modelData.v)
                    }
                }

                // ---- arrowheads ----
                Toggle {
                    visible: root.k === "arrow"
                    icon: "navigation"
                    tip: Tr.tr("Filled head")
                    checked: root.vHead === "filled"
                    onClicked: root.win.setProp("head", root.vHead === "filled" ? "open" : "filled")
                }
                Toggle {
                    visible: root.k === "arrow"
                    icon: "sync_alt"
                    tip: Tr.tr("Heads at both ends")
                    checked: root.vBoth
                    onClicked: root.win.setProp("both", !root.vBoth)
                }

                // ---- fill and corners ----
                Repeater {
                    model: root.k === "rect" || root.k === "ellipse" ? [
                        {
                            v: "none",
                            i: "check_box_outline_blank",
                            t: Tr.tr("No fill")
                        },
                        {
                            v: "solid",
                            i: "square",
                            t: Tr.tr("Filled")
                        },
                        {
                            v: "second",
                            i: "format_color_fill",
                            t: Tr.tr("Filled with the second colour")
                        }
                    ] : []

                    Toggle {
                        required property var modelData

                        icon: modelData.i
                        tip: modelData.t
                        checked: root.vFill === modelData.v
                        label.fill: modelData.v === "none" ? 0 : 1
                        onClicked: root.win.setProp("fill", modelData.v)
                    }
                }
                MaterialIcon {
                    visible: root.k === "rect"
                    Layout.alignment: Qt.AlignVCenter
                    text: "rounded_corner"
                    color: Colours.palette.m3onSurfaceVariant
                }
                Slider {
                    visible: root.k === "rect"
                    implicitWidth: root.compact ? 52 : 72
                    from: 0
                    to: 60
                    value: root.vRadius
                    onMoved: root.win.setProp("radius", Math.round(value))
                }

                // ---- text ----
                TextButton {
                    id: fontBtn

                    visible: root.showFont
                    Layout.alignment: Qt.AlignVCenter
                    Layout.maximumWidth: 150
                    type: TextButton.Tonal
                    text: root.vFamily
                    label.elide: Text.ElideRight
                    onClicked: fontMenu.expanded = !fontMenu.expanded
                }
                PaintButton {
                    visible: root.showFont
                    icon: "text_decrease"
                    tip: Tr.tr("Smaller text")
                    onClicked: root.win.setProp("fontSize", Math.max(8, Math.round(root.vFont / 1.15)))
                }
                Label {
                    visible: root.showFont
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignHCenter
                    text: `${Math.round(root.vFont)} px`
                }
                PaintButton {
                    visible: root.showFont
                    icon: "text_increase"
                    tip: Tr.tr("Bigger text")
                    onClicked: root.win.setProp("fontSize", Math.min(400, Math.round(root.vFont * 1.15) + 1))
                }
                Toggle {
                    visible: root.k === "text"
                    icon: "format_bold"
                    tip: Tr.tr("Bold")
                    checked: root.vBold
                    onClicked: root.win.setProp("bold", !root.vBold)
                }
                Toggle {
                    visible: root.k === "text"
                    icon: "format_italic"
                    tip: Tr.tr("Italic")
                    checked: root.vItalic
                    onClicked: root.win.setProp("italic", !root.vItalic)
                }
                Toggle {
                    visible: root.k === "text"
                    icon: "label"
                    tip: Tr.tr("Background (second colour)")
                    checked: root.vBox
                    onClicked: root.win.setProp("box", !root.vBox)
                }
                Toggle {
                    visible: root.k === "text"
                    icon: "format_color_text"
                    tip: Tr.tr("Outline, for busy pictures")
                    checked: root.vOutline
                    onClicked: root.win.setProp("outline", !root.vOutline)
                }

                // ---- numbered steps ----
                Label {
                    visible: root.k === "step" && !root.hasSel
                    text: Tr.tr("Next: %1").arg(root.win.nextStep())
                }

                // ---- redaction ----
                Repeater {
                    model: root.k === "redact" ? [
                        {
                            v: "pixelate",
                            i: "grid_on",
                            t: Tr.tr("Pixelate")
                        },
                        {
                            v: "blur",
                            i: "blur_on",
                            t: Tr.tr("Blur")
                        },
                        {
                            v: "box",
                            i: "square",
                            t: Tr.tr("Black box (safest)")
                        }
                    ] : []

                    Toggle {
                        required property var modelData

                        icon: modelData.i
                        tip: modelData.t
                        checked: root.vMode === modelData.v
                        label.fill: modelData.v === "box" ? 1 : 0
                        onClicked: root.win.setProp("redactMode", modelData.v)
                    }
                }
                Slider {
                    visible: root.k === "redact" && root.vMode !== "box"
                    from: 4
                    to: 40
                    value: root.vStrength
                    onMoved: root.win.setProp("redactStrength", Math.round(value))
                }

                // ---- spotlight ----
                Toggle {
                    visible: root.k === "spotlight"
                    icon: "crop_square"
                    tip: Tr.tr("Rectangle")
                    label.fill: 0
                    checked: root.vShape === "rect"
                    onClicked: root.win.setProp("spotShape", "rect")
                }
                Toggle {
                    visible: root.k === "spotlight"
                    icon: "circle"
                    tip: Tr.tr("Ellipse")
                    label.fill: 0
                    checked: root.vShape === "ellipse"
                    onClicked: root.win.setProp("spotShape", "ellipse")
                }
                MaterialIcon {
                    visible: root.k === "spotlight"
                    Layout.alignment: Qt.AlignVCenter
                    text: "brightness_4"
                    color: Colours.palette.m3onSurfaceVariant
                }
                Slider {
                    visible: root.k === "spotlight"
                    from: 0.15
                    to: 0.9
                    value: root.vDim
                    onMoved: root.win.setProp("spotDim", Math.round(value * 100) / 100)
                }

                // ---- magnifier ----
                MaterialIcon {
                    visible: root.k === "magnifier"
                    Layout.alignment: Qt.AlignVCenter
                    text: "zoom_in"
                    color: Colours.palette.m3onSurfaceVariant
                }
                Slider {
                    visible: root.k === "magnifier"
                    from: 1.5
                    to: 6
                    value: root.vZoom
                    onMoved: root.win.setProp("magZoom", Math.round(value * 10) / 10)
                }
                Label {
                    visible: root.k === "magnifier"
                    Layout.preferredWidth: 36
                    text: `${root.vZoom.toFixed(1)}×`
                }
            }
        }

        Rectangle {
            visible: propsFlick.interactive && !propsFlick.atXBeginning
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.padding.medium
            width: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Colours.palette.m3surfaceContainer
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0)
                }
            }
        }
        Rectangle {
            visible: propsFlick.interactive && !propsFlick.atXEnd
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: Tokens.padding.medium
            width: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0)
                }
                GradientStop {
                    position: 1
                    color: Colours.palette.m3surfaceContainer
                }
            }
        }
    }

    function openPicker(which: string, anchor: Item): void {
        pickerFor = which;
        picker.value = which === "second" ? win.second : vColour;
        const p = anchor.mapToItem(picker.parent, anchor.width / 2, 0);
        picker.x = Math.max(8, Math.min(picker.parent.width - picker.width - 8, p.x - picker.width / 2));
        picker.y = p.y - picker.implicitHeight - 12;
        picker.open = true;
    }

    // closes the picker on a click elsewhere
    MouseArea {
        parent: root.win.contentItem
        anchors.fill: parent
        z: 940
        visible: picker.open
        acceptedButtons: Qt.AllButtons
        onPressed: m => {
            picker.open = false;
            root.win.canvasRef.forceActiveFocus();
            root.win.rememberColour(root.pickerFor === "second" ? root.win.second : root.win.colour);
            m.accepted = true;
        }
    }

    ColourPicker {
        id: picker

        parent: root.win.contentItem
        onPicked: c => root.win.setProp(root.pickerFor, c)
    }

    Menu {
        id: fontMenu

        parent: root.win.contentItem
        attachTo: fontBtn
        attachSideY: Menu.Top
        thisSideY: Menu.Bottom
        active: root.fontItems.find(i => i.text === root.vFamily) ?? null
        items: root.fontItems
    }

    property list<MenuItem> fontItems

    Component {
        id: fontItemComp

        MenuItem {
            text: ""
        }
    }

    Component.onCompleted: {
        const installed = Qt.fontFamilies();
        // the shell's own font first, whatever name fontconfig lists it under
        const own = Tokens.font.body.small.family;
        const wanted = [own, "Inter", "Rubik", "Roboto", "Noto Sans", "Cantarell", "DejaVu Sans", "Liberation Sans", "Noto Serif", "DejaVu Serif", "Liberation Serif", "JetBrains Mono", "Fira Code", "DejaVu Sans Mono", "Comic Neue", "Caveat", "Patrick Hand"];
        const seen = new Set();
        const list = [];
        for (const f of wanted) {
            if (f && (f === own || installed.includes(f)) && !seen.has(f)) {
                seen.add(f);
                const item = fontItemComp.createObject(root, {
                    text: f
                });
                item.clicked.connect(() => root.win.setProp("family", f));
                list.push(item);
            }
        }
        for (const f of ["Sans Serif", "Serif", "Monospace"]) {
            const item = fontItemComp.createObject(root, {
                text: f
            });
            item.clicked.connect(() => root.win.setProp("family", f));
            list.push(item);
        }
        fontItems = list;
    }
}
