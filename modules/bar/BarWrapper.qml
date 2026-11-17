pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    // The pill: it floats this far from the edge, springs out like the top island, and its
    // shape (drawn by the drawers, ContentWindow) spans pillTop .. pillBottom
    readonly property int pillGap: Tokens.spacing.medium
    readonly property Item barItem: content.item
    readonly property real pillX: content.x
    readonly property real pillTop: (content.item as Bar)?.pillTop ?? height / 2
    readonly property real pillBottom: (content.item as Bar)?.pillBottom ?? height / 2
    readonly property real reveal: revealSpring.value
    // The pill sits in the middle of the edge
    readonly property real pillCenter: height / 2
    // Desktop mode (hyprflow) keeps the bar, with its taskbar, always shown.
    readonly property bool persistent: Config.bar.persistent
    // (the pill has a gap on both sides: the one after it is where its menus start)
    readonly property int exclusiveZone: !disabled && (persistent || screenState.bar) ? contentWidth + pillGap * 2 : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (persistent || screenState.bar || isHovered || minimizePeek)
    property bool isHovered
    // A window minimizing into (or restoring out of) the pill while it's hidden (hyprflow's
    // genie): the pill comes out meanwhile, so the window pours into an icon that's there
    property bool minimizePeek

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "minimized")
                return;
            const address = event.data.split(",")[0];
            const t = Hyprland.toplevels.values.find(t => t.address === address);
            if (t && t.monitor?.name === root.screen?.name) {
                root.minimizePeek = true;
                peekTimer.restart();
            }
        }

        target: Hyprland
    }

    Timer {
        id: peekTimer

        // (the genie's ~0.5 s, and a moment to see where it went)
        interval: 1300
        onTriggered: root.minimizePeek = false
    }

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(y: real): void {
        (content.item as Bar)?.checkPopout(y);
    }

    function handleWheel(y: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(y, angleDelta);
    }

    SpringValue {
        id: revealSpring

        stiffness: 300
        damping: 33
        target: root.shouldBeVisible ? 1 : 0
    }

    visible: width > Config.border.thickness
    implicitWidth: fullscreen ? 0 : Config.border.thickness + (contentWidth + pillGap * 2 - Config.border.thickness) * Math.max(0, reveal)

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // It stays put a gap from the edge (it grows in place)
        x: root.pillGap

        active: root.shouldBeVisible || root.reveal > 0.01
        // Its contents fade in as it comes out
        opacity: Math.min(1, Math.max(0, (root.reveal - 0.4) / 0.5))
        scale: 0.6 + 0.4 * Math.min(1, Math.max(0, root.reveal))

        sourceComponent: Bar {
            width: root.contentWidth
            pillCenter: root.pillCenter
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }
}
