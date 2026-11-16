pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils

// Paint: draw on a screenshot, an image or a blank page. Pen, highlighter, line, arrow,
// rectangle, ellipse, text and crop; colours, thickness, undo/redo; copy (Ctrl+C) and save
// (Ctrl+S: a new file next to the image, or Pictures/Paint for a blank page; never over the
// original). Everything is drawn in the image's own pixels, so the saved file has its full size.
FloatingWindow {
    id: win

    property string source
    readonly property bool blank: source === ""
    readonly property string fileName: blank ? "" : source.split("/").pop()

    // Tools and their look
    property string tool: "pen"
    property color colour: swatches[0]
    property real thickness: 4
    readonly property var swatches: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#0a84ff", "#af52de", "#ffffff", "#000000"]

    // The drawing: committed shapes, what's being drawn, undo/redo
    property var items: []
    property var history: [] // {kind: "add"} or {kind: "crop", from, to}
    property var future: []
    property var draft: null
    property var draftPoints: []
    property int draftRev
    property bool dirty

    // The page, in image pixels
    readonly property real pageWidth: blank ? 1920 : Math.max(1, image.implicitWidth)
    readonly property real pageHeight: blank ? 1080 : Math.max(1, image.implicitHeight)
    property rect crop: Qt.rect(0, 0, pageWidth, pageHeight)
    property rect cropDraft: crop
    readonly property bool cropping: tool === "crop"
    // The part shown: all of it while cropping, else the crop
    readonly property rect shown: cropping ? Qt.rect(0, 0, pageWidth, pageHeight) : crop
    // Image pixels -> screen pixels
    readonly property real fit: Math.min((viewport.width - 32) / shown.width, (viewport.height - 32) / shown.height, 2)

    title: blank ? Tr.tr("Paint") : Tr.tr("Paint — %1").arg(fileName)
    color: Colours.palette.m3surface
    implicitWidth: 1280
    implicitHeight: 820
    minimumSize.width: 760
    minimumSize.height: 480

    onVisibleChanged: {
        if (!visible)
            destroy();
    }

    function toImage(x: real, y: real): point {
        return Qt.point(x / fit + shown.x, y / fit + shown.y);
    }

    function commit(item: var): void {
        items = [...items, item];
        history = [...history, {
                kind: "add"
            }];
        future = [];
        dirty = true;
    }

    function undo(): void {
        if (history.length === 0)
            return;
        const step = history[history.length - 1];
        history = history.slice(0, -1);
        if (step.kind === "crop") {
            crop = step.from;
            future = [...future, step];
        } else {
            future = [...future, {
                    kind: "add",
                    item: items[items.length - 1]
                }];
            items = items.slice(0, -1);
        }
        dirty = true;
    }

    function redo(): void {
        if (future.length === 0)
            return;
        const step = future[future.length - 1];
        future = future.slice(0, -1);
        if (step.kind === "crop")
            crop = step.to;
        else
            items = [...items, step.item];
        history = [...history, {
                kind: step.kind,
                from: step.from,
                to: step.to
            }];
        dirty = true;
    }

    function applyCrop(): void {
        const r = cropDraft;
        if (r.width >= 4 && r.height >= 4 && (r.x !== crop.x || r.y !== crop.y || r.width !== crop.width || r.height !== crop.height)) {
            history = [...history, {
                    kind: "crop",
                    from: crop,
                    to: r
                }];
            future = [];
            crop = r;
            dirty = true;
        }
        tool = "pen";
    }

    function setTool(t: string): void {
        finishText();
        if (t === "crop")
            cropDraft = crop;
        tool = t;
    }

    // The picture as drawn (crop applied), at the image's own size
    function render(done: var): void {
        finishText();
        if (cropping)
            tool = "pen";
        Qt.callLater(() => page.grabToImage(result => done(result), Qt.size(Math.round(crop.width), Math.round(crop.height))));
    }

    function stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
    }

    function save(): void {
        const dir = blank ? `${Paths.pictures}/Paint` : source.slice(0, source.lastIndexOf("/"));
        const base = blank ? `Paint_${stamp()}` : `${fileName.replace(/\.[^.]+$/, "")}-edited-${stamp()}`;
        const path = `${dir}/${base}.png`;
        const tmp = `/tmp/caelestia-paint-${stamp()}.png`;
        render(result => {
            if (!result.saveToFile(tmp)) {
                Quickshell.execDetached(["notify-send", "-a", "Paint", "-u", "critical", Tr.tr("Couldn't save the picture"), Paths.shortenHome(path)]);
                return;
            }
            // (the folder may not exist yet: made, then the picture moved in)
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && mv "$1" "$2" && notify-send -a Paint -i "$2" -h "string:image-path:$2" "$3" "$4" || notify-send -a Paint -u critical "$5" "$4"', "sh", tmp, path, Tr.tr("Picture saved"), Paths.shortenHome(path), Tr.tr("Couldn't save the picture")]);
            dirty = false;
        });
    }

    function copy(): void {
        const tmp = `/tmp/caelestia-paint-${stamp()}.png`;
        render(result => {
            if (result.saveToFile(tmp)) {
                Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "$1"; rm -f "$1"`, "sh", tmp]);
                copiedTip.restart();
            }
        });
    }

    // Text being typed (tool "text"): committed on Enter, a click elsewhere or another tool
    function finishText(): void {
        if (!textEntry.visible)
            return;
        if (textEntry.text.trim() !== "")
            commit({
                kind: "text",
                x: textEntry.at.x,
                y: textEntry.at.y,
                text: textEntry.text,
                colour: colour.toString(),
                size: Math.max(14, thickness * 6) / fit
            });
        textEntry.visible = false;
        textEntry.text = "";
    }

    // The polyline(s) a shape is drawn with, in image pixels
    function strokesOf(d: var): var {
        if (!d)
            return [[], []];
        const p = d.points;
        if (d.kind === "pen" || d.kind === "highlighter")
            return [p, []];
        const a = p[0], b = p[p.length - 1];
        if (!a || !b)
            return [[], []];
        if (d.kind === "line")
            return [[a, b], []];
        if (d.kind === "arrow") {
            const ang = Math.atan2(b.y - a.y, b.x - a.x);
            const len = Math.min(Math.hypot(b.x - a.x, b.y - a.y) * 0.5, d.width * 4 + 14 / fit);
            const head = [Qt.point(b.x - len * Math.cos(ang - 0.45), b.y - len * Math.sin(ang - 0.45)), b, Qt.point(b.x - len * Math.cos(ang + 0.45), b.y - len * Math.sin(ang + 0.45))];
            return [[a, b], head];
        }
        if (d.kind === "rect")
            return [[a, Qt.point(b.x, a.y), b, Qt.point(a.x, b.y), a], []];
        if (d.kind === "ellipse") {
            const cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2, rx = Math.abs(b.x - a.x) / 2, ry = Math.abs(b.y - a.y) / 2;
            const pts = [];
            for (let i = 0; i <= 96; i++)
                pts.push(Qt.point(cx + rx * Math.cos(i / 96 * Math.PI * 2), cy + ry * Math.sin(i / 96 * Math.PI * 2)));
            return [pts, []];
        }
        return [[], []];
    }

    Shortcut {
        sequences: [StandardKey.Undo]
        onActivated: win.undo()
    }
    Shortcut {
        sequences: [StandardKey.Redo, "Ctrl+Y"]
        onActivated: win.redo()
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        enabled: !textEntry.visible
        onActivated: win.copy()
    }
    Shortcut {
        sequences: [StandardKey.Save]
        onActivated: win.save()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: win.cropping
        onActivated: win.applyCrop()
    }
    Shortcut {
        sequence: "Escape"
        enabled: win.cropping || textEntry.visible
        onActivated: {
            if (textEntry.visible) {
                textEntry.visible = false;
                textEntry.text = "";
            } else {
                win.tool = "pen";
            }
        }
    }

    FileDialog {
        id: openDialog

        title: Tr.tr("Open a picture")
        filterLabel: Tr.tr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => Paint.open(path)
    }

    Item {
        id: viewport

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: toolbar.top
        anchors.bottomMargin: Tokens.spacing.medium
        clip: true

        // What's drawn, at screen size
        Item {
            id: stage

            anchors.centerIn: parent
            width: win.shown.width * win.fit
            height: win.shown.height * win.fit

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                color: "transparent"
                border.color: Colours.palette.m3outlineVariant
            }

            // The picture in image pixels, clipped to the shown part; also what's saved
            Item {
                id: page

                width: win.shown.width
                height: win.shown.height
                clip: true
                transformOrigin: Item.TopLeft
                scale: win.fit

                Item {
                    x: -win.shown.x
                    y: -win.shown.y
                    width: win.pageWidth
                    height: win.pageHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: win.blank
                        color: "white"
                    }

                    Image {
                        id: image

                        anchors.fill: parent
                        visible: !win.blank
                        source: win.blank ? "" : (win.source.startsWith("/") ? `file://${win.source}` : win.source)
                        cache: false
                        smooth: true
                        mipmap: true
                    }

                    Repeater {
                        model: win.items

                        Item {
                            id: shapeItem

                            required property var modelData

                            anchors.fill: parent

                            Loader {
                                anchors.fill: parent
                                active: shapeItem.modelData.kind !== "text"
                                sourceComponent: strokeComp

                                onLoaded: item.d = shapeItem.modelData
                            }

                            Text {
                                visible: shapeItem.modelData.kind === "text"
                                x: shapeItem.modelData.x ?? 0
                                y: shapeItem.modelData.y ?? 0
                                text: shapeItem.modelData.text ?? ""
                                color: shapeItem.modelData.colour ?? "white"
                                font.family: Tokens.font.body.small.family
                                font.pixelSize: shapeItem.modelData.size ?? 24
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // What's being drawn
                    Loader {
                        anchors.fill: parent
                        active: win.draft !== null
                        sourceComponent: strokeComp

                        onLoaded: item.d = Qt.binding(() => {
                            win.draftRev;
                            return win.draft ? Object.assign({}, win.draft, {
                                points: win.draftPoints.slice()
                            }) : null;
                        })
                    }
                }
            }

            // Cropping: the dimmed outside and the frame
            Item {
                anchors.fill: parent
                visible: win.cropping

                readonly property rect r: Qt.rect(win.cropDraft.x * win.fit, win.cropDraft.y * win.fit, win.cropDraft.width * win.fit, win.cropDraft.height * win.fit)

                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width
                    height: parent.r.y
                    color: Qt.alpha("black", 0.55)
                }
                Rectangle {
                    x: 0
                    y: parent.r.y + parent.r.height
                    width: parent.width
                    height: parent.height - y
                    color: Qt.alpha("black", 0.55)
                }
                Rectangle {
                    x: 0
                    y: parent.r.y
                    width: parent.r.x
                    height: parent.r.height
                    color: Qt.alpha("black", 0.55)
                }
                Rectangle {
                    x: parent.r.x + parent.r.width
                    y: parent.r.y
                    width: parent.width - x
                    height: parent.r.height
                    color: Qt.alpha("black", 0.55)
                }
                Rectangle {
                    x: parent.r.x
                    y: parent.r.y
                    width: parent.r.width
                    height: parent.r.height
                    color: "transparent"
                    border.color: "white"
                    border.width: 2
                }
            }

            // Drawing
            MouseArea {
                anchors.fill: parent
                cursorShape: win.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor

                property point start

                onPressed: event => {
                    const p = win.toImage(event.x, event.y);
                    if (win.tool === "text") {
                        win.finishText();
                        textEntry.at = p;
                        textEntry.visible = true;
                        textEntry.forceActiveFocus();
                        return;
                    }
                    win.finishText();
                    start = p;
                    if (win.cropping) {
                        win.cropDraft = Qt.rect(p.x, p.y, 0, 0);
                        return;
                    }
                    const hl = win.tool === "highlighter";
                    win.draftPoints = [p];
                    win.draft = {
                        kind: win.tool,
                        colour: hl ? Qt.alpha(win.colour, 0.4).toString() : win.colour.toString(),
                        width: (hl ? win.thickness * 4 : win.thickness) / win.fit
                    };
                    win.draftRev++;
                }
                onPositionChanged: event => {
                    if (!pressed)
                        return;
                    const p = win.toImage(Math.max(0, Math.min(width, event.x)), Math.max(0, Math.min(height, event.y)));
                    if (win.cropping) {
                        win.cropDraft = Qt.rect(Math.min(start.x, p.x), Math.min(start.y, p.y), Math.abs(p.x - start.x), Math.abs(p.y - start.y));
                        return;
                    }
                    if (!win.draft)
                        return;
                    const pts = win.draftPoints;
                    if (win.draft.kind === "pen" || win.draft.kind === "highlighter") {
                        const last = pts[pts.length - 1];
                        if (Math.hypot(p.x - last.x, p.y - last.y) * win.fit < 1.5)
                            return;
                        pts.push(p);
                    } else {
                        // Shift: straight lines at 45° steps, squares and circles
                        let q = p;
                        if (event.modifiers & Qt.ShiftModifier) {
                            const dx = p.x - start.x, dy = p.y - start.y;
                            if (win.draft.kind === "line" || win.draft.kind === "arrow") {
                                const a = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
                                const l = Math.hypot(dx, dy);
                                q = Qt.point(start.x + l * Math.cos(a), start.y + l * Math.sin(a));
                            } else {
                                const s = Math.max(Math.abs(dx), Math.abs(dy));
                                q = Qt.point(start.x + Math.sign(dx || 1) * s, start.y + Math.sign(dy || 1) * s);
                            }
                        }
                        // (a copy: `start` is a live reference to this MouseArea's property)
                        win.draftPoints = [Qt.point(start.x, start.y), Qt.point(q.x, q.y)];
                    }
                    win.draftRev++;
                }
                onReleased: {
                    if (win.cropping || !win.draft)
                        return;
                    const d = Object.assign({}, win.draft, {
                        points: win.draftPoints.slice()
                    });
                    win.draft = null;
                    win.draftPoints = [];
                    // A click without a drag: a dot for the pen, nothing for shapes
                    if (d.points.length === 1 && (d.kind === "pen" || d.kind === "highlighter"))
                        d.points.push(Qt.point(d.points[0].x + 0.01, d.points[0].y));
                    if (d.points.length >= 2)
                        win.commit(d);
                }
            }

            // Typing text where it was clicked
            TextInput {
                id: textEntry

                property point at

                visible: false
                x: (at.x - win.shown.x) * win.fit
                y: (at.y - win.shown.y) * win.fit
                color: win.colour
                font.family: Tokens.font.body.small.family
                font.pixelSize: Math.max(14, win.thickness * 6)
                font.weight: Font.DemiBold
                cursorVisible: visible
                onAccepted: win.finishText()

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    z: -1
                    color: "transparent"
                    border.color: Colours.palette.m3primary
                    radius: 4
                }
            }
        }
    }

    // A shape drawn as up to two polylines (the arrow's head is the second)
    Component {
        id: strokeComp

        Shape {
            id: shape

            property var d: null
            readonly property var lines: win.strokesOf(d)

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: shape.d?.colour ?? "transparent"
                strokeWidth: shape.d?.width ?? 1
                fillColor: "transparent"
                capStyle: shape.d?.kind === "highlighter" ? ShapePath.FlatCap : ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: shape.lines[0]
                }
            }

            ShapePath {
                strokeColor: shape.d?.colour ?? "transparent"
                strokeWidth: shape.d?.width ?? 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: shape.lines[1]
                }
            }
        }
    }

    // The tools, along the bottom
    StyledRect {
        id: toolbar

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium
        implicitWidth: row.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: row.implicitHeight + Tokens.padding.small * 2
        radius: height / 2
        color: Colours.palette.m3surfaceContainer

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            Repeater {
                model: [
                    {
                        key: "pen",
                        icon: "draw",
                        tip: Tr.tr("Pen")
                    },
                    {
                        key: "highlighter",
                        icon: "ink_highlighter",
                        tip: Tr.tr("Highlighter")
                    },
                    {
                        key: "line",
                        icon: "horizontal_rule",
                        tip: Tr.tr("Line (Shift: straight)")
                    },
                    {
                        key: "arrow",
                        icon: "arrow_right_alt",
                        tip: Tr.tr("Arrow (Shift: straight)")
                    },
                    {
                        key: "rect",
                        icon: "rectangle",
                        tip: Tr.tr("Rectangle (Shift: square)")
                    },
                    {
                        key: "ellipse",
                        icon: "circle",
                        tip: Tr.tr("Ellipse (Shift: circle)")
                    },
                    {
                        key: "text",
                        icon: "title",
                        tip: Tr.tr("Text")
                    },
                    {
                        key: "crop",
                        icon: "crop",
                        tip: Tr.tr("Crop (Enter to apply)")
                    }
                ]

                IconButton {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    type: IconButton.Tonal
                    checked: win.tool === modelData.key
                    icon: modelData.icon
                    onClicked: win.setTool(modelData.key)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 24
                color: Colours.palette.m3outlineVariant
            }

            Repeater {
                model: win.swatches

                Rectangle {
                    id: swatch

                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: modelData
                    border.width: Qt.colorEqual(win.colour, modelData) ? 3 : 1
                    border.color: Qt.colorEqual(win.colour, modelData) ? Colours.palette.m3primary : Colours.palette.m3outline

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.colour = swatch.modelData
                    }
                }
            }

            StyledSlider {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 110
                implicitHeight: 28
                from: 1
                to: 24
                value: win.thickness
                onMoved: win.thickness = Math.round(value)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 24
                color: Colours.palette.m3outlineVariant
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Text
                icon: "undo"
                disabled: win.history.length === 0
                onClicked: win.undo()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Text
                icon: "redo"
                disabled: win.future.length === 0
                onClicked: win.redo()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: win.cropping
                type: IconButton.Filled
                icon: "check"
                onClicked: win.applyCrop()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Text
                icon: "folder_open"
                onClicked: openDialog.open()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Text
                icon: copiedTip.running ? "inventory" : "content_copy"
                onClicked: win.copy()

                Timer {
                    id: copiedTip

                    interval: 1500
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                type: IconButton.Filled
                icon: "save"
                onClicked: win.save()
            }
        }
    }
}
