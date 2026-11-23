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

    property bool hovered
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool shouldBeActive: screenState.osd && Config.osd.enabled
    readonly property real open: Math.min(1, Math.max(0, openSpring.value))
    readonly property real offsetScale: 1 - open

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

    // An island floating a gap from the right edge, grown out of a small capsule there (like the
    // top island out of its pill)
    readonly property real floatGap: Tokens.spacing.medium
    // (over the last bit the capsule itself shrinks away: nothing left on the edge)
    readonly property real tail: Math.min(1, open / 0.2)
    readonly property real fullWidth: content.implicitWidth
    readonly property real fullHeight: content.implicitHeight
    // Its height for the hover zone on the edge while it's closed (unloaded then: no size of
    // its own), the last one it had, at first one slider's
    property real zoneHeight: Tokens.sizes.osd.sliderHeight + 44 + Tokens.padding.large * 2

    onFullHeightChanged: {
        if (fullHeight > 0 && !screenState.osdExpanded)
            zoneHeight = fullHeight;
    }

    onOffsetScaleChanged: {
        if (offsetScale >= 0.998 && !shouldBeActive && screenState.osdExpanded)
            screenState.osdExpanded = false;
    }

    visible: open > 0.002 || shouldBeActive
    anchors.rightMargin: floatGap
    implicitWidth: Math.round(fullWidth * (0.6 + 0.4 * open) * tail)
    implicitHeight: Math.round(fullHeight * (0.35 + 0.65 * open) * tail)
    clip: true
    // (its contents fade in once it has grown enough to hold them)
    opacity: Math.min(1, Math.max(0, (open - 0.6) / 0.35))

    SpringValue {
        id: openSpring

        stiffness: 260
        damping: 33
        target: root.shouldBeActive ? 1 : 0
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

    Connections {
        function onOsdExpandedChanged(): void {
            if (root.screenState.osdExpanded) {
                root.show();
                timer.stop();
            } else if (root.screenState.osd) {
                timer.restart();
            }
        }

        target: root.screenState
    }

    Timer {
        id: timer

        interval: root.Config.osd.hideDelay
        onTriggered: {
            if (!root.hovered && !root.screenState.osdExpanded)
                root.screenState.osd = false;
        }
    }

    Loader {
        id: content

        anchors.centerIn: parent

        asynchronous: false
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
