pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "Geometry.js" as G

// One drawing item, in image pixels (see Geometry.js for the kinds and their fields).
// `pixels`: the layer with the picture and pasted images, which redaction and the magnifier sample.
Item {
    id: root

    property var d: null
    property Item pixels: null
    property real docWidth
    property real docHeight
    readonly property string kind: d?.kind ?? ""

    // The laid-out size of a text or callout's text, for selection boxes (image pixels)
    readonly property size textSize: kind === "text" ? Qt.size(textBox.width, textBox.height) : Qt.size(0, 0)

    anchors.fill: parent

    // plain {x, y} points (what's saved) as Qt points for PathPolyline
    function qp(pts: var): var {
        return (pts ?? []).map(p => Qt.point(p.x, p.y));
    }

    function alpha(c: var, o: real): color {
        const col = Qt.color(c ?? "black");
        return Qt.rgba(col.r, col.g, col.b, col.a * (o ?? 1));
    }

    // ---- strokes and shapes ----
    Loader {
        anchors.fill: parent
        active: G.isPointsKind(root.kind)

        sourceComponent: Shape {
            id: shape

            readonly property var lines: G.strokesOf(root.d)
            readonly property var mainPath: root.qp(lines[0])
            readonly property bool closedShape: root.kind === "rect" || root.kind === "ellipse"
            readonly property color strokeCol: root.alpha(root.d?.colour, root.d?.opacity)
            readonly property real w: root.d?.width ?? 1
            readonly property int dashStyle: (root.d?.dash ?? "solid") === "solid" ? ShapePath.SolidLine : ShapePath.DashLine

            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            ShapePath {
                strokeColor: shape.strokeCol
                strokeWidth: shape.w
                strokeStyle: shape.dashStyle
                dashPattern: root.d?.dash === "dot" ? [0.01, 2] : [3, 2]
                fillColor: {
                    if (!shape.closedShape || !root.d?.fill || root.d.fill === "none")
                        return "transparent";
                    return root.d.fill === "second" ? root.alpha(root.d.fillColour, root.d.opacity) : shape.strokeCol;
                }
                capStyle: root.kind === "highlighter" ? ShapePath.FlatCap : ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: shape.mainPath
                }
            }

            // Arrowheads (one per end): open (two strokes) or filled triangles
            ShapePath {
                id: head1

                readonly property var head: shape.lines[1][0] ?? []

                strokeColor: head.length ? shape.strokeCol : "transparent"
                strokeWidth: shape.w
                fillColor: head.length && root.d?.head === "filled" ? shape.strokeCol : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.qp(head1.head.length && root.d?.head === "filled" ? head1.head.concat([head1.head[0]]) : head1.head)
                }
            }

            ShapePath {
                id: head2

                readonly property var head: shape.lines[1][1] ?? []

                strokeColor: head.length ? shape.strokeCol : "transparent"
                strokeWidth: shape.w
                fillColor: head.length && root.d?.head === "filled" ? shape.strokeCol : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.qp(head2.head.length && root.d?.head === "filled" ? head2.head.concat([head2.head[0]]) : head2.head)
                }
            }
        }
    }

    // ---- text ----
    Item {
        id: textBox

        readonly property real pad: (root.d?.box ?? "") !== "" ? Math.round((root.d?.size ?? 24) * 0.3) : 0

        visible: root.kind === "text"
        x: root.d?.x ?? 0
        y: root.d?.y ?? 0
        width: textItem.implicitWidth + pad * 2
        height: textItem.implicitHeight + pad * 2

        Rectangle {
            anchors.fill: parent
            visible: textBox.pad > 0
            radius: textBox.pad
            color: root.d?.box || "transparent"
        }

        Text {
            id: textItem

            x: textBox.pad
            y: textBox.pad
            text: root.kind === "text" ? (root.d?.text ?? "") : ""
            color: root.d?.colour ?? "black"
            font.family: root.d?.family ?? "sans-serif"
            font.pixelSize: Math.max(4, Math.round(root.d?.size ?? 24))
            font.bold: root.d?.bold ?? false
            font.italic: root.d?.italic ?? false
            style: root.d?.outline ? Text.Outline : Text.Normal
            styleColor: G.contrastOn(Qt.color(root.d?.colour ?? "black"))
            textFormat: Text.PlainText
        }
    }

    // ---- pasted image ----
    Loader {
        active: root.kind === "image"
        x: root.d?.x ?? 0
        y: root.d?.y ?? 0
        width: root.d?.w ?? 0
        height: root.d?.h ?? 0

        sourceComponent: Image {
            source: root.d?.src ? (root.d.src.startsWith("/") ? `file://${root.d.src}` : root.d.src) : ""
            fillMode: Image.Stretch
            smooth: true
            mipmap: true
            cache: false
            opacity: root.d?.opacity ?? 1
        }
    }

    // ---- redaction: pixelate, blur or a solid box ----
    Loader {
        active: root.kind === "redact" && root.d.w > 0 && root.d.h > 0
        x: root.d?.x ?? 0
        y: root.d?.y ?? 0
        width: root.d?.w ?? 0
        height: root.d?.h ?? 0

        sourceComponent: Item {
            readonly property string mode: root.d?.mode ?? "pixelate"
            readonly property real strength: root.d?.strength ?? 12

            clip: true

            Rectangle {
                anchors.fill: parent
                visible: parent.mode === "box"
                color: root.d?.colour ?? "black"
            }

            // Pixelate: the area rendered at 1/strength size and shown without smoothing
            ShaderEffectSource {
                anchors.fill: parent
                visible: parent.mode === "pixelate"
                sourceItem: parent.mode === "pixelate" ? root.pixels : null
                sourceRect: Qt.rect(root.d.x, root.d.y, root.d.w, root.d.h)
                textureSize: Qt.size(Math.max(1, Math.ceil(root.d.w / parent.strength)), Math.max(1, Math.ceil(root.d.h / parent.strength)))
                smooth: false
                mipmap: false
            }

            // Blur: a margin around the area is sampled so the edges blur too
            Item {
                anchors.fill: parent
                visible: parent.mode === "blur"

                ShaderEffectSource {
                    id: blurSrc

                    readonly property real m: Math.min(64, parent.parent.strength * 2)

                    x: -m
                    y: -m
                    width: root.d.w + m * 2
                    height: root.d.h + m * 2
                    visible: false
                    sourceItem: parent.visible ? root.pixels : null
                    sourceRect: Qt.rect(root.d.x - m, root.d.y - m, root.d.w + m * 2, root.d.h + m * 2)
                }

                MultiEffect {
                    x: blurSrc.x
                    y: blurSrc.y
                    width: blurSrc.width
                    height: blurSrc.height
                    source: blurSrc
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: Math.min(64, Math.max(8, Math.round(parent.parent.strength * 2.5)))
                    blurMultiplier: 1.2
                }
            }
        }
    }

    // ---- numbered step ----
    Rectangle {
        visible: root.kind === "step"
        x: (root.d?.x ?? 0) - width / 2
        y: (root.d?.y ?? 0) - height / 2
        width: (root.d?.size ?? 16) * 2
        height: width
        radius: width / 2
        color: root.d?.colour ?? "red"
        border.width: Math.max(1, width * 0.06)
        border.color: G.contrastOn(Qt.color(root.d?.colour ?? "red"))

        Text {
            anchors.centerIn: parent
            text: root.d?.n ?? ""
            color: G.contrastOn(Qt.color(root.d?.colour ?? "red"))
            font.pixelSize: Math.max(4, Math.round((root.d?.size ?? 16) * 1.05))
            font.bold: true
        }
    }

    // ---- callout (speech bubble) ----
    Loader {
        anchors.fill: parent
        active: root.kind === "callout"

        sourceComponent: Item {
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.d?.colour ?? "black"
                    strokeWidth: Math.max(1, (root.d?.size ?? 20) / 8)
                    fillColor: root.d?.fillColour ?? "white"
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: root.qp(G.calloutPoints(root.d))
                    }
                }
            }

            Text {
                readonly property real pad: Math.max(6, (root.d?.size ?? 20) * 0.5)

                x: (root.d?.x ?? 0) + pad
                y: (root.d?.y ?? 0) + pad
                width: Math.max(1, (root.d?.w ?? 0) - pad * 2)
                height: Math.max(1, (root.d?.h ?? 0) - pad * 2)
                visible: !(root.d?.editing ?? false)
                text: root.d?.text ?? ""
                color: G.contrastOn(Qt.color(root.d?.fillColour ?? "white"))
                font.family: root.d?.family ?? "sans-serif"
                font.pixelSize: Math.max(4, Math.round(root.d?.size ?? 20))
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }

    // ---- spotlight: everything but the area dimmed ----
    Loader {
        anchors.fill: parent
        active: root.kind === "spotlight"

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.rgba(0, 0, 0, root.d?.dim ?? 0.55)
                fillRule: ShapePath.OddEvenFill

                PathPolyline {
                    path: [Qt.point(-1, -1), Qt.point(root.docWidth + 1, -1), Qt.point(root.docWidth + 1, root.docHeight + 1), Qt.point(-1, root.docHeight + 1), Qt.point(-1, -1)]
                }
                PathPolyline {
                    path: {
                        const r = {
                            x: root.d?.x ?? 0,
                            y: root.d?.y ?? 0,
                            w: root.d?.w ?? 0,
                            h: root.d?.h ?? 0
                        };
                        return root.qp(root.d?.shape === "ellipse" ? G.ellipsePoints(r, 120) : G.roundedRectPoints(r, Math.min(12, r.w / 4, r.h / 4)));
                    }
                }
            }
        }
    }

    // ---- magnifier ----
    Loader {
        active: root.kind === "magnifier" && (root.d?.r ?? 0) > 1
        x: (root.d?.x ?? 0) - (root.d?.r ?? 0)
        y: (root.d?.y ?? 0) - (root.d?.r ?? 0)
        width: (root.d?.r ?? 0) * 2
        height: width

        sourceComponent: Item {
            id: lens

            readonly property real r: root.d.r
            readonly property real zf: Math.max(1.1, root.d.zoom ?? 2)

            ShaderEffectSource {
                id: lensSrc

                anchors.fill: parent
                visible: false
                sourceItem: root.pixels
                sourceRect: Qt.rect(root.d.x - lens.r / lens.zf, root.d.y - lens.r / lens.zf, lens.r * 2 / lens.zf, lens.r * 2 / lens.zf)
                textureSize: Qt.size(Math.ceil(lens.r * 2), Math.ceil(lens.r * 2))
                smooth: true
            }

            Rectangle {
                id: lensMask

                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: lensSrc
                maskEnabled: true
                maskSource: lensMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: Math.max(2, lens.r * 0.05)
                border.color: "white"
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.5)
            }
        }
    }
}
