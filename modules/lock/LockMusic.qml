pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import M3Shapes
import Caelestia.Config
import Caelestia.Services
import qs.services

Item {
    id: root

    property real morph: 0
    property real spin: 0
    property real trackPos: player?.position ?? 0

    readonly property var player: Players.active
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string artUrl: Players.getArtUrl(player)
    readonly property string title: (player?.trackTitle ?? "Nothing playing") || "Unknown track"
    readonly property string artist: (player?.trackArtist ?? "") || "Unknown artist"
    readonly property real length: player?.length ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, trackPos / length)) : 0

    readonly property real fade: Math.max(0, Math.min(1, (morph - 0.35) / 0.3))
    readonly property real bgFade: Math.max(0, Math.min(1, morph * 2))
    readonly property real idleFade: 1 - Math.max(0, Math.min(1, morph * 3))
    readonly property real corner: 32

    readonly property var bars: {
        const v = Audio.cava.values;
        const n = NebulaTheme.lock.visualizerBars;
        const out = [];
        for (let j = 0; j < n; j++) {
            const a = Math.floor(j * v.length / n);
            const b = Math.max(a + 1, Math.floor((j + 1) * v.length / n));
            let sum = 0;
            let count = 0;
            for (let i = a; i < b && i < v.length; i++) {
                sum += v[i];
                count++;
            }
            out.push(count > 0 ? Math.max(0.06, Math.min(1, sum / count)) : 0.06);
        }
        return out;
    }

    ServiceRef {
        service: root.visible && root.playing ? Audio.cava : null
    }

    Connections {
        target: root.player
        function onPositionChanged(): void {
            root.trackPos = root.player?.position ?? 0;
        }
        function onTrackTitleChanged(): void {
            root.trackPos = root.player?.position ?? 0;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.playing && root.visible
        onTriggered: {
            if (root.player)
                root.trackPos = Math.min(root.length > 0 ? root.length : root.trackPos + 1, root.trackPos + 1);
        }
    }

    FrameAnimation {
        running: root.playing && root.visible
        onTriggered: root.spin += frameTime * 15
    }

    Item {
        anchors.fill: parent
        opacity: root.bgFade
        visible: opacity > 0

        Rectangle {
            anchors.fill: parent
            radius: root.corner
            color: Qt.alpha(NebulaTheme.colors.primaryContainer, NebulaTheme.lock.surfaceTint)
        }

        Rectangle {
            id: mask

            anchors.fill: parent
            radius: root.corner
            visible: false
            layer.enabled: true
        }

        Item {
            id: artLayer

            anchors.fill: parent
            visible: false
            layer.enabled: true

            BlurredArt {
                anchors.fill: parent
                source: root.artUrl
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: artLayer
            maskEnabled: true
            maskSource: mask
            opacity: 0.9
        }

        Rectangle {
            anchors.fill: parent
            radius: root.corner
            color: NebulaTheme.colors.primaryContainer
            opacity: 0.45
        }
    }

    Item {
        id: idle

        readonly property real d: width * 0.68
        readonly property real ringR: d / 2 + 11

        anchors.fill: parent
        opacity: root.idleFade
        visible: opacity > 0

        Shape {
            anchors.fill: parent

            ShapePath {
                strokeColor: Qt.alpha(NebulaTheme.colors.textOnSurface, 0.16)
                strokeWidth: 3
                fillColor: "transparent"

                PathAngleArc {
                    centerX: idle.width / 2
                    centerY: idle.ringR + 2
                    radiusX: idle.ringR
                    radiusY: idle.ringR
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: NebulaTheme.colors.primary
                strokeWidth: 3
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"

                PathAngleArc {
                    centerX: idle.width / 2
                    centerY: idle.ringR + 2
                    radiusX: idle.ringR
                    radiusY: idle.ringR
                    startAngle: -90
                    sweepAngle: 360 * root.progress
                }
            }
        }

        ShapedArt {
            x: (idle.width - width) / 2
            y: idle.ringR + 2 - height / 2
            width: idle.d
            height: width
            shape: MaterialShape.Cookie9Sided
            color: NebulaTheme.colors.primary
            source: root.artUrl
            sourceSize: Qt.size(width * 2, height * 2)
            shapeRotation: root.spin
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: idle.ringR * 2 + 16
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.title
                font.family: NebulaTheme.font.family
                font.pixelSize: NebulaTheme.font.large
                font.weight: Font.Medium
                color: NebulaTheme.colors.textOnSurface
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.artist
                font.family: NebulaTheme.font.family
                font.pixelSize: NebulaTheme.font.normal
                color: Qt.alpha(NebulaTheme.colors.textOnSurface, 0.7)
            }
        }
    }

    Item {
        id: design

        width: NebulaTheme.lock.activeMusicWidth
        height: NebulaTheme.lock.activeMusicHeight
        scale: root.width / width
        transformOrigin: Item.TopLeft
        opacity: root.fade
        visible: opacity > 0

        Column {
            x: 24
            y: 18
            width: parent.width - 48
            spacing: 8
            enabled: root.fade > 0.9

            ShapedArt {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                shape: MaterialShape.Cookie9Sided
                color: NebulaTheme.colors.primary
                source: root.artUrl
                sourceSize: Qt.size(width * 2, height * 2)
                shapeRotation: root.spin
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.title
                font.family: NebulaTheme.font.family
                font.pixelSize: NebulaTheme.font.large + 2
                font.weight: Font.Medium
                color: NebulaTheme.colors.textOnPrimaryContainer
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.artist
                font.family: NebulaTheme.font.family
                font.pixelSize: NebulaTheme.font.normal
                color: Qt.alpha(NebulaTheme.colors.textOnPrimaryContainer, 0.8)
            }

            WavyProgress {
                width: parent.width
                height: 14
                progress: root.progress
                animated: root.playing
                color: NebulaTheme.colors.primary
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                NebulaIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_previous"
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player?.previous()
                }

                NebulaPlayButton {
                    anchors.verticalCenter: parent.verticalCenter
                    playing: root.playing
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player?.togglePlaying()
                }

                NebulaIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_next"
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player?.next()
                }
            }
        }

        GlassRect {
            x: 16
            y: parent.height - 16 - height
            width: parent.width - 32
            height: NebulaTheme.lock.eqHeight - 24
            radius: NebulaTheme.radius.large
            fill: NebulaTheme.colors.surfaceContainer
            tint: 0.45
            light: 0.06

            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: Math.max(2, (width - count * 5) / Math.max(1, count - 1))

                readonly property int count: NebulaTheme.lock.visualizerBars

                Repeater {
                    model: parent.count

                    Item {
                        required property int index

                        width: 5
                        height: parent.height

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: Math.max(6, parent.height * (root.bars[parent.index] ?? 0.06))
                            radius: width / 2
                            color: parent.index % 3 === 0 ? NebulaTheme.colors.tertiary : NebulaTheme.colors.primary

                            Behavior on height {
                                NumberAnimation {
                                    duration: 85
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
