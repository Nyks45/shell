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
    // Desktop mode (hyprflow) keeps the bar, with its taskbar, always shown.
    readonly property bool persistent: Config.bar.persistent
    readonly property int exclusiveZone: !disabled && (persistent || screenState.bar) ? contentWidth : Config.border.thickness
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

    clip: true
    visible: width > Config.border.thickness
    implicitWidth: fullscreen ? 0 : Config.border.thickness

    states: State {
        name: "visible"
        when: root.shouldBeVisible

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

        active: root.shouldBeVisible

        sourceComponent: Bar {
            width: root.contentWidth
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }
}
