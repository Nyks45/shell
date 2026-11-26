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
        }

        ShaderEffect {
            anchors.fill: parent
            visible: photo.status === Image.Ready
            property var snapshot: photo
            property real progress: LiveWallpaper.transitionProgress
            property int effect: window.transition?.effect ?? -1
            property vector4d crop: Qt.vector4d(window.crop.x, window.crop.y, window.crop.width, window.crop.height)
            fragmentShader: Quickshell.shellPath("assets/shaders/wallpaper-transition.frag.qsb")
        }
    }
}
