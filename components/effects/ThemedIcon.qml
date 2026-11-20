pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Caelestia.Images
import qs.services

// Renders a theme/app icon with automatic contrast repair for low-contrast monochrome
// icons (or full theme tinting when monochrome is true, e.g. in Settings lists).
Item {
    id: root

    property alias source: icon.source
    property alias mipmap: icon.mipmap
    property alias asynchronous: icon.asynchronous
    property alias status: icon.status
    property alias implicitSize: icon.implicitSize
    property color colour: Colours.palette.m3onSurfaceVariant
    property bool monochrome: false

    readonly property bool needsTint: monochrome || (analyser.analysed && (Colours.light ? analyser.monochromeLight : analyser.monochromeDark))

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Item {
        id: tintedWrap

        anchors.fill: parent
        layer.enabled: root.needsTint
        layer.effect: Colouriser {
            sourceColor: analyser.dominantColour
            colorizationColor: root.colour
            brightness: analyser.monochromeDark ? Math.max(0.5, 1 - analyser.dominantColour.hslLightness) : analyser.monochromeLight ? 0 : Math.max(0, 0.35 - analyser.luminance)
        }

        IconImage {
            id: icon

            anchors.fill: parent
            asynchronous: true
            onStatusChanged: {
                if (status === Image.Ready && String(source).length > 0)
                    analyser.requestUpdate();
            }
            onSourceChanged: {
                if (status === Image.Ready && String(source).length > 0)
                    analyser.requestUpdate();
            }
        }
    }

    ImageAnalyser {
        id: analyser

        sourceItem: icon
        rescaleSize: 48
    }
}
