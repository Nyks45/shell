import QtQuick
import M3Shapes

Item {
    id: root

    property bool running: false
    property int delay: 0
    property bool shown: running && delay <= 0
    property bool contained: true
    property int interval: 520
    property color color: NebulaTheme.colors.primary
    property color containerColor: NebulaTheme.colors.primaryContainer
    property int index: 0

    readonly property var shapes: [
        MaterialShape.SoftBurst,
        MaterialShape.Cookie9Sided,
        MaterialShape.Pentagon,
        MaterialShape.Pill,
        MaterialShape.Sunny,
        MaterialShape.Cookie4Sided,
        MaterialShape.Oval
    ]

    implicitWidth: 48
    implicitHeight: 48
    visible: opacity > 0
    opacity: shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: NebulaTheme.anim.fast
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.containerColor
        visible: root.contained
    }

    MaterialShape {
        id: shape

        anchors.centerIn: parent
        width: parent.width * 0.56
        height: parent.height * 0.56
        shape: root.shapes[root.index]
        color: root.color
        animationDuration: NebulaTheme.anim.medium
        animationEasing.type: Easing.BezierSpline
        animationEasing.bezierCurve: NebulaTheme.anim.emphasizedDecel

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 3600
            loops: Animation.Infinite
            running: root.shown && root.visible
        }
    }

    onRunningChanged: {
        if (!running)
            shown = false;
        else if (delay <= 0)
            shown = true;
    }

    Timer {
        interval: root.delay
        running: root.running && !root.shown && root.delay > 0
        onTriggered: root.shown = true
    }

    Timer {
        interval: root.interval
        repeat: true
        triggeredOnStart: true
        running: root.shown && root.visible
        onTriggered: root.index = (root.index + 1) % root.shapes.length
    }
}
