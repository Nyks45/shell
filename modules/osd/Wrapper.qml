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
    property real offsetScale: 1
    // Wave motion: rises and spreads from where it was opened (components/WaveMotion.qml)
    readonly property WaveMotion drop: WaveMotion {
        panel: root
        screenState: root.screenState
        edge: "right"
        fullAlong: root.content.implicitHeight || 0
        fullDepth: root.content.implicitWidth
        space: root.parent?.parent ?? null
        finalCenter: (space?.height ?? 0) / 2
        offsetScale: root.offsetScale
        open: root.shouldBeActive
    }
    readonly property real dropRadius: drop.radius
    readonly property alias content: content

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
    anchors.rightMargin: drop.active ? 0 : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: drop.active ? drop.depth : content.implicitWidth
    clip: true // (the drop reveals the content; always on: toggling it left rounded masks black)
    implicitHeight: drop.active ? drop.along : content.implicitHeight
    opacity: drop.active ? 1 : 1 - offsetScale

    ShellMotion {
        target: root
        to: root.shouldBeActive ? 0 : 1
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

        opacity: root.drop.contentOpacity
        // Where it sits: one expression (never swapped anchors); with the drop, at its final
        // place while the wave grows over it
        x: root.drop.active ? root.width - root.drop.fullDepth : 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.drop.offset

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
