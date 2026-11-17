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

    // With the pill bar: an island floating a gap from the right edge, grown out of a small
    // capsule there (like the top island out of its pill)
    readonly property bool island: Config.bar.pill
    readonly property real floatGap: Tokens.spacing.medium
    readonly property real open: 1 - offsetScale
    // (over the last bit the capsule itself shrinks away: nothing left on the edge)
    readonly property real tail: Math.min(1, open / 0.2)
    readonly property real fullWidth: content.implicitWidth
    readonly property real fullHeight: content.implicitHeight
    // Its height for the hover zone on the edge while it's closed (unloaded then: no size of
    // its own), the last one it had, at first one slider's
    property real zoneHeight: Tokens.sizes.osd.sliderHeight + Tokens.padding.large * 2

    onFullHeightChanged: {
        if (fullHeight > 0)
            zoneHeight = fullHeight;
    }

    visible: offsetScale < 1
    anchors.rightMargin: island ? floatGap : (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: island ? fullWidth * (0.6 + 0.4 * open) * tail : fullWidth
    implicitHeight: island ? fullHeight * (0.35 + 0.65 * open) * tail : fullHeight
    clip: island
    // (the island's contents fade in once it has grown enough to hold them)
    opacity: island ? Math.min(1, Math.max(0, (open - 0.6) / 0.35)) : 1 - offsetScale

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

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.island ? undefined : parent.left
        anchors.horizontalCenter: root.island ? parent.horizontalCenter : undefined

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
            island: root.island
        }
    }
}
