import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.Multimedia
import qs.services

Item {
    id: root

    required property var screen
    property real openT: 0
    property real closeT: 0
    property real modeT: 0
    property bool closing: false
    property bool bootLock: false

    readonly property string videoPath: "/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/frieren-pixel-sorcery.mp4"
    readonly property bool hasVideo: CUtils.fileExists(videoPath)
    readonly property bool useWallpaperMode: Config.lock.useWallpaper || bootLock
    readonly property real backdropFade: closing ? Math.max(0, 1 - Math.pow(Math.max(0, (closeT - 0.5) / 0.5), 2)) : 1
    readonly property real targetBlur: 0.28 + 0.57 * root.modeT
    readonly property real blurAmount: (bootLock ? targetBlur : Math.min(1, Math.pow(Math.max(0, openT), 0.45)) * targetBlur) * backdropFade
    // At boot the backdrop fades in over the dark scene once its picture is there. "Ready"
    // comes a little before the picture is on screen and can flicker while a video takes
    // over from its still, so it is waited out and then latched (shown at once, or faded
    // from a moving target, the picture popped in).
    readonly property bool mediaReady: !hasVideo || animatedBg.ready
    property bool mediaLatched: false
    property real mediaIn: !bootLock || mediaLatched ? 1 : 0

    Timer {
        interval: 350
        running: root.bootLock && root.mediaReady && root.openT > 0.02 && !root.mediaLatched
        onTriggered: root.mediaLatched = true
    }

    Behavior on mediaIn {
        enabled: root.bootLock

        NumberAnimation {
            duration: 700
            easing.type: Easing.InOutSine
        }
    }

    Rectangle {
        anchors.fill: parent
        color: NebulaTheme.lock.space
    }

    Item {
        id: sourceLayer

        anchors.fill: parent
        opacity: root.mediaIn * root.backdropFade

        layer.enabled: root.blurAmount > 0.005
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: root.blurAmount
            blurMax: NebulaTheme.lock.blurMax
        }

        Loader {
            anchors.fill: parent
            active: !root.useWallpaperMode
            sourceComponent: ScreencopyView {
                captureSource: root.screen
            }
        }

        Item {
            anchors.fill: parent
            visible: root.useWallpaperMode

            Image {
                anchors.fill: parent
                visible: !root.hasVideo
                source: !root.hasVideo && Wallpapers.current ? `file://${Wallpapers.current}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: true
            }

            Visual {
                id: animatedBg

                anchors.fill: parent
                source: root.hasVideo ? root.videoPath : Wallpapers.current
                playing: root.visible && !root.closing
                animate: false
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: NebulaTheme.lock.space
        opacity: Math.min(1, root.openT * 1.6) * (0.18 + 0.26 * root.modeT) * root.backdropFade
    }
}
