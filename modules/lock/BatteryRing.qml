import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real level: 0.85
    property bool low: false

    readonly property real thickness: NebulaTheme.batteryRing.thickness
    readonly property real r: (width - thickness) / 2
    readonly property real sweep: 360 * Math.max(0, Math.min(1, level))
    readonly property real gap: 14

    property real wobble: 0
    property real phase: 0
    property int waves: 8

    Behavior on level {
        NumberAnimation {
            duration: NebulaTheme.anim.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: NebulaTheme.anim.standard
        }
    }

    implicitWidth: NebulaTheme.batteryRing.size
    implicitHeight: NebulaTheme.batteryRing.size

    function arcPoints(startDeg: real, sweepDeg: real): var {
        const points = [];
        const cx = width / 2;
        const cy = height / 2;
        const steps = Math.max(2, Math.ceil(sweepDeg / 3));
        for (let i = 0; i <= steps; i++) {
            const a = (startDeg + sweepDeg * i / steps) * Math.PI / 180;
            const rr = r + wobble * Math.sin(waves * a + phase);
            points.push(Qt.point(cx + rr * Math.cos(a), cy + rr * Math.sin(a)));
        }
        return points;
    }

    readonly property var indicatorPoints: arcPoints(-90, sweep)
    readonly property var trackPoints: arcPoints(-90 + sweep + gap, Math.max(0, 360 - sweep - gap * 2))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.low ? NebulaTheme.colors.errorColor : NebulaTheme.colors.primary
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline {
                path: root.indicatorPoints
            }
        }

        ShapePath {
            strokeColor: Qt.alpha(NebulaTheme.colors.primary, NebulaTheme.batteryRing.trackOpacity)
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline {
                path: root.trackPoints
            }
        }
    }
}
