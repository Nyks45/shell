pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real boost: 0
    property real iconOpacity: 1
    property real spinPhase: 0
    property real pulse: 0
    property bool bootLoading: false
    property var levels: []
    readonly property real radius: width / 2

    implicitWidth: NebulaTheme.lock.holeSize
    implicitHeight: NebulaTheme.lock.holeSize

    FrameAnimation {
        running: root.visible
        onTriggered: root.spinPhase += frameTime * (0.5 + 9 * root.boost + 4 * root.pulse) * 1.6
    }

    function rand(seed: real): real {
        const x = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    Shape {
        id: halo

        readonly property real r: root.width * 1.6

        anchors.centerIn: parent
        width: r * 2
        height: r * 2
        z: -1
        opacity: Math.min(1, 0.65 + 0.7 * root.pulse)

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: halo.r
                centerY: halo.r
                centerRadius: halo.r
                focalX: halo.r
                focalY: halo.r
                GradientStop {
                    position: 0.2
                    color: Qt.alpha(NebulaTheme.colors.primary, 0.32)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(NebulaTheme.colors.primary, 0)
                }
            }
            startX: 0
            startY: 0
            PathLine {
                x: halo.width
                y: 0
            }
            PathLine {
                x: halo.width
                y: halo.height
            }
            PathLine {
                x: 0
                y: halo.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Repeater {
        model: NebulaTheme.lock.ringDots

        Rectangle {
            id: dot

            required property int index

            readonly property real ring: 1.5 + root.rand(index + 1) * 1.9
            readonly property real angle: root.rand(index + 50) * Math.PI * 2 + root.spinPhase / Math.pow(ring, 1.5)
            readonly property real unit: (((angle + Math.PI / 2) % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2) / (Math.PI * 2) * 10
            readonly property int low: Math.floor(unit) % 10
            readonly property real mix: unit - Math.floor(unit)
            readonly property real level: root.levels.length === 10 ? (root.levels[low] ?? 0) * (1 - mix) + (root.levels[(low + 1) % 10] ?? 0) * mix : 0

            width: 3 + 2.5 * root.pulse + 4 * level
            height: width
            radius: width / 2
            x: root.width / 2 + Math.cos(angle) * ring * root.radius * (1 + NebulaTheme.lock.pulseGain * root.pulse + 0.25 * level) - width / 2
            y: root.height / 2 + Math.sin(angle) * ring * root.radius * (1 + NebulaTheme.lock.pulseGain * root.pulse + 0.25 * level) * NebulaTheme.lock.ringTilt - width / 2
            z: Math.sin(angle) > 0 ? 2 : 0
            color: index % 3 === 0 ? NebulaTheme.colors.tertiary : NebulaTheme.colors.primary
            opacity: 0.75 + 0.25 * level
        }
    }

    Rectangle {
        id: holeCircle

        anchors.centerIn: parent
        width: root.width
        height: width
        radius: width / 2
        color: "black"
        border.width: 2
        border.color: Qt.alpha(NebulaTheme.colors.inversePrimary, 0.75)
        z: 1
    }

    LoadingIndicator {
        anchors.centerIn: parent
        width: root.width * 0.44
        height: width
        contained: false
        color: NebulaTheme.colors.primary
        running: root.bootLoading
        visible: opacity > 0
        opacity: root.bootLoading ? root.iconOpacity : 0
        z: 3
    }

    Text {
        anchors.centerIn: parent
        text: "lock"
        font.family: NebulaTheme.font.icons
        font.pixelSize: root.width * 0.26
        color: NebulaTheme.colors.textOnSurface
        opacity: root.bootLoading ? 0 : root.iconOpacity
        z: 3

        Behavior on opacity {
            NumberAnimation {
                duration: NebulaTheme.anim.medium
            }
        }
    }

    Text {
        id: bootStatusLabel

        anchors.top: holeCircle.bottom
        anchors.topMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Starting desktop…"
        font.family: NebulaTheme.font.family
        font.pixelSize: NebulaTheme.font.normal
        font.weight: Font.Medium
        color: NebulaTheme.colors.textOnSurface
        opacity: root.bootLoading ? pulseAlpha * labelIn : 0
        visible: opacity > 0.01
        z: 3

        property real pulseAlpha: 0.85
        // Fades in: the boot splash under the first frame has no label
        property real labelIn: 0

        NumberAnimation on labelIn {
            running: root.bootLoading && root.visible
            to: 1
            duration: 600
        }

        SequentialAnimation on pulseAlpha {
            loops: Animation.Infinite
            running: root.bootLoading && root.visible
            NumberAnimation {
                to: 0.48
                duration: 700
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0.88
                duration: 700
                easing.type: Easing.InOutSine
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: NebulaTheme.anim.medium
            }
        }
    }
}
