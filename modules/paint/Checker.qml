import QtQuick
import QtQuick.Effects

// A light/dark checkerboard: what shows through transparent pixels
Item {
    id: root

    property real cell: 10
    property real radius
    property color light: "#ffffff"
    property color dark: "#d6d6d6"

    layer.enabled: radius > 0
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.fillStyle = root.light;
            ctx.fillRect(0, 0, width, height);
            ctx.fillStyle = root.dark;
            const c = Math.max(2, root.cell);
            for (let y = 0; y < height; y += c)
                for (let x = ((y / c) % 2) * c; x < width; x += c * 2)
                    ctx.fillRect(x, y, c, c);
        }
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}
