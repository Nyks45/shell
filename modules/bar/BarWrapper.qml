pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
    // The pill (Config.bar.pill): it floats this far from the edge, springs out like the top
    // island, and its shape (drawn by the drawers, ContentWindow) spans pillTop .. pillBottom
    readonly property bool pill: Config.bar.pill
    readonly property int pillGap: pill ? Tokens.spacing.medium : 0
    readonly property Item barItem: content.item
    readonly property real pillX: content.x
    readonly property real pillTop: (content.item as Bar)?.pillTop ?? height / 2
    readonly property real pillBottom: (content.item as Bar)?.pillBottom ?? height / 2
    readonly property real reveal: revealSpring.value
    // Where the pill shows: the height the edge was touched at (Interactions)
    property real pillCenter: height / 2
    // Desktop mode (hyprflow) keeps the bar, with its taskbar, always shown.
    readonly property bool persistent: Config.bar.persistent
    readonly property int exclusiveZone: !disabled && (persistent || screenState.bar) ? contentWidth + pillGap : Config.border.thickness
    // The power menu opens from the bar's power button (a popout, not the
    // drawer at the right edge) when the bar has one
    readonly property bool sessionAtBar: !disabled && Config.session.enabled && Config.bar.entries.values.some(e => e.enabled && e.id === "power")
    readonly property bool sessionOpen: sessionAtBar && screenState.session
    // (kept shown while its power menu is open, the pointer being on the menu)
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (persistent || screenState.bar || isHovered || sessionOpen)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(y: real): void {
        (content.item as Bar)?.checkPopout(y);
    }

    function handleWheel(y: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(y, angleDelta);
    }

    function syncSession(): void {
        if (!sessionAtBar)
            return;
        if (screenState.session) {
            popouts.currentName = "session";
            popouts.currentCenter = Qt.binding(() => {
                const bar = content.item as Bar;
                const button = bar?.powerButton;
                return button ? button.mapToItem(bar, 0, button.implicitHeight / 2).y : root.height;
            });
            popouts.hasCurrent = true;
        } else if (popouts.currentName === "session") {
            popouts.hasCurrent = false;
        }
    }

    Binding {
        target: root.screenState
        property: "sessionAtBar"
        value: root.sessionAtBar
    }

    Connections {
        function onSessionChanged(): void {
            root.syncSession();
        }

        target: root.screenState
    }

    // Closed from the popout side (Escape, an action, another popout): the
    // session state follows
    Connections {
        function onHasCurrentChanged(): void {
            if (!root.popouts.hasCurrent && root.popouts.currentName === "session" && root.screenState.session)
                root.screenState.session = false;
        }

        function onCurrentNameChanged(): void {
            if (root.popouts.currentName !== "session" && root.screenState.session && root.sessionAtBar)
                root.screenState.session = false;
        }

        target: root.popouts
    }

    SpringValue {
        id: revealSpring

        stiffness: 300
        damping: 33
        target: root.shouldBeVisible ? 1 : 0
    }

    clip: !pill
    visible: width > Config.border.thickness
    implicitWidth: fullscreen ? 0 : pill ? Config.border.thickness + (contentWidth + pillGap - Config.border.thickness) * Math.max(0, reveal) : Config.border.thickness

    states: State {
        name: "visible"
        when: root.shouldBeVisible && !root.pill

        PropertyChanges {
            root.implicitWidth: root.contentWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        active: root.shouldBeVisible || (root.pill && root.reveal > 0.01)
        // The pill's contents fade in as it comes out
        opacity: root.pill ? Math.min(1, Math.max(0, (root.reveal - 0.3) / 0.6)) : 1

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
