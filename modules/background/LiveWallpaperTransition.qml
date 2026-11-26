pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Variants {
    model: Quickshell.screens.filter(screen => LiveWallpaper.switchingWallpaper?.outputs[screen.name])

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property var transition: LiveWallpaper.switchingWallpaper
        readonly property rect crop: transition?.outputs[modelData.name] ?? Qt.rect(0, 0, 1, 1)
        readonly property int effect: transition?.effect ?? -1
        readonly property bool hasPieces: effect === 16 || effect === 23

        screen: modelData
        visible: LiveWallpaper.transitionPrepared
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "live-wallpaper-transition"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Connections {
            target: photo.Window.window
            function onFrameSwapped(): void {
                if (photo.status === Image.Ready)
                    LiveWallpaper.transitionDrawn(window.modelData.name);
            }
        }

        Image {
            id: photo

            visible: false
            source: window.transition ? `file://${window.transition.photo}` : ""
            cache: false
            mipmap: window.effect === 25
        }

        ShaderEffect {
            anchors.fill: parent
            visible: photo.status === Image.Ready && !window.hasPieces
            property var snapshot: photo
            property real progress: LiveWallpaper.transitionProgress
            property int effect: window.effect
            property vector4d crop: Qt.vector4d(window.crop.x, window.crop.y, window.crop.width, window.crop.height)
            property vector3d seed: window.transition?.seed ?? Qt.vector3d(0.5, 0.5, 0.5)
            property vector2d snapshotSize: Qt.vector2d(photo.sourceSize.width, photo.sourceSize.height)
            property real aspectRatio: width / Math.max(1, height)
            readonly property real outputScale: (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1
            property real displayWidth: Math.max(1, width * outputScale)
            property real displayHeight: Math.max(1, height * outputScale)
            fragmentShader: Quickshell.shellPath("assets/shaders/wallpaper-transition.frag.qsb")
        }

        Repeater {
            model: !window.hasPieces || photo.status !== Image.Ready ? 0 : window.effect === 16 ? 28 : 80

            ShaderEffect {
                required property int index
                anchors.fill: parent
                property var snapshot: photo
                property real progress: LiveWallpaper.transitionProgress
                property int effect: window.effect
                property vector4d crop: Qt.vector4d(window.crop.x, window.crop.y, window.crop.width, window.crop.height)
                property real aspectRatio: width / Math.max(1, height)
                property int pieceIndex: index
                property vector2d viewport: Qt.vector2d(width, height)
                vertexShader: Quickshell.shellPath("assets/shaders/wallpaper-pieces.vert.qsb")
                fragmentShader: Quickshell.shellPath("assets/shaders/wallpaper-pieces.frag.qsb")
            }
        }
    }
}
