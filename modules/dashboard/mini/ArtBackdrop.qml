pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Images
import qs.components
import qs.services

// A music card's backdrop in the song's own colours (like Android's media notifications): the
// cover, blurred and darkened, fills the card; `accent` is the cover's main colour, brightened
// to read on it. With no cover: the card's usual colour.
ClipRect {
    id: root

    property string source
    readonly property bool hasArt: art.status === Image.Ready
    readonly property color accent: {
        const c = analyser.dominantColour;
        if (!hasArt || c.a === 0)
            return Colours.palette.m3primary;
        // (bright and saturated enough to stand out on the dark cover)
        return Qt.hsla(c.hslHue < 0 ? 0 : c.hslHue, Math.max(0.45, c.hslSaturation), Math.max(0.68, c.hslLightness), 1);
    }
    readonly property color accentText: "#101014"

    color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)

    Image {
        id: art

        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 160
        visible: false
        onStatusChanged: if (status === Image.Ready) reanalyse.restart()
        onSourceChanged: if (status === Image.Ready) reanalyse.restart()
    }

    // Grab after at least one rendered frame so MultiEffect reflects the new cover
    // (ImageAnalyser.source uses QImage(path), which skips https:// / file:// URLs).
    Timer {
        id: reanalyse

        interval: 60
        onTriggered: if (root.hasArt) analyser.requestUpdate()
    }

    Item {
        anchors.fill: parent
        opacity: root.hasArt ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        MultiEffect {
            id: blurred

            anchors.fill: parent
            source: art
            visible: root.hasArt
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.25
        }

        // Darkened, more at the bottom where the controls are
        Rectangle {
            anchors.fill: parent
            visible: root.hasArt
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.38)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.62)
                }
            }
        }
    }

    ImageAnalyser {
        id: analyser

        sourceItem: root.hasArt ? blurred : null
        rescaleSize: 64
    }
}
