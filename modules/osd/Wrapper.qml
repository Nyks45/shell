pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property bool sidebarOrSessionVisible

    property bool hovered
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool shouldBeActive: screenState.osd && Config.osd.enabled && !(screenState.utilities && Config.utilities.enabled)
    property real offsetScale: shouldBeActive ? 0 : 1
    // Nebula motion (Wallpaper & style > Nebula > Animations > Shell): expands out of the edge like
    // Nebula's media island, its content revealed in place, instead of sliding in
    readonly property bool expandStyle: GlobalConfig.appearance.style.shellAnim === "nebula"
    readonly property real openT: 1 - offsetScale
    property real sidebarOffset: sidebarOrSessionVisible ? 12 : 0

    property real volume
    property bool muted
    property real sourceVolume
    property bool sourceMuted
    property real brightness

    function show(): void {
        screenState.osd = true;
        timer.restart();
    }

    Component.onCompleted: {
        volume = Audio.volume;
        muted = Audio.muted;
        sourceVolume = Audio.sourceVolume;
        sourceMuted = Audio.sourceMuted;
        brightness = root.monitor?.brightness ?? 0;
    }

    visible: offsetScale < 1
    anchors.rightMargin: expandStyle ? 0 : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: content.implicitWidth * (expandStyle ? openT : 1)
    clip: expandStyle
    implicitHeight: content.implicitHeight
    opacity: expandStyle ? 1 : 1 - offsetScale
    // Expanding: the body grows first, then the content fades in and settles (closing: the
    // content goes first, then the body folds back into the edge)
    readonly property real contentT: expandStyle ? Math.max(0, Math.min(1, (openT - 0.35) / 0.6)) : 1

    Behavior on offsetScale {
        Anim {}
    }

    Connections {
        function onMutedChanged(): void {
            root.show();
            root.muted = Audio.muted;
        }

        function onVolumeChanged(): void {
            root.show();
            root.volume = Audio.volume;
        }

        function onSourceMutedChanged(): void {
            root.show();
            root.sourceMuted = Audio.sourceMuted;
        }

        function onSourceVolumeChanged(): void {
            root.show();
            root.sourceVolume = Audio.sourceVolume;
        }

        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            root.show();
            root.brightness = root.monitor?.brightness ?? 0;
        }

        target: root.monitor
    }

    Timer {
        id: timer

        interval: root.Config.osd.hideDelay
        onTriggered: {
            if (!root.hovered)
                root.screenState.osd = false;
        }
    }

    Loader {
        id: content

        opacity: root.contentT
        scale: 0.96 + 0.04 * root.contentT
        transformOrigin: Item.Right

        anchors.verticalCenter: parent.verticalCenter
        // (expanding: stays put at the right edge and is revealed; sliding: moves with the panel)
        anchors.left: root.expandStyle ? undefined : parent.left
        anchors.right: root.expandStyle ? parent.right : undefined

        asynchronous: true
        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            monitor: root.monitor
            screenState: root.screenState
            volume: root.volume
            muted: root.muted
            sourceVolume: root.sourceVolume
            sourceMuted: root.sourceMuted
            brightness: root.brightness
        }
    }
}
