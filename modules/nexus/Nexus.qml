pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.polkit

Item {
    id: root

    readonly property NexusState nState: NexusState {
        id: nState

        onClose: root.close()
    }
    property color blobColour: Colours.tPalette.m3surfaceContainerLow
    // Has focus: a password request (polkit) then shows inside this window
    readonly property bool windowActive: Window.active

    signal close

    // The live wallpapers' Workshop: fetched as the settings open, cleared as
    // they close. A settings window shows the password prompt itself.
    Component.onCompleted: {
        LiveWallpaper.settingsOpened();
        if (nState.isWindow)
            Polkit.addHost(root);
    }
    Component.onDestruction: {
        LiveWallpaper.settingsClosed();
        Polkit.removeHost(root);
    }

    implicitWidth: Math.round(implicitHeight * Tokens.sizes.nexus.ratio)
    implicitHeight: Math.round(nState.screen.height * Tokens.sizes.nexus.heightMult)

    Behavior on blobColour {
        CAnim {}
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.focus = true
    }

    // The mouse's back button: up one sub-page (or out of the search)
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: root.nState.back()
    }

    BlobGroup {
        id: blobGroup

        smoothing: root.Tokens.rounding.medium
        color: root.blobColour
    }

    BlobInvertedRect {
        anchors.fill: parent
        group: blobGroup
        opacity: root.blobColour.a
        radius: Tokens.rounding.large

        borderLeft: navPane.width + navPane.anchors.margins * 2
        borderRight: Tokens.padding.medium
        borderTop: Tokens.padding.medium
        borderBottom: Tokens.padding.medium
    }

    // The drawer's pop-out button. A window has none: its title bar (hyprflow)
    // closes it, and Super+Q does without one.
    BlobRect {
        id: windowBtnRect

        visible: !root.nState.isWindow
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.nState.isWindow ? 0 : Tokens.padding.extraSmall

        // Out of the group too, so the background doesn't keep its bump
        group: root.nState.isWindow ? null : blobGroup
        opacity: root.blobColour.a
        radius: Tokens.rounding.medium

        implicitWidth: windowBtn.implicitWidth + (root.nState.isWindow ? Tokens.padding.extraSmall : Tokens.padding.small) * 2
        implicitHeight: windowBtn.implicitHeight + (root.nState.isWindow ? Tokens.padding.extraSmall : Tokens.padding.small)
    }

    IconButton {
        id: windowBtn

        visible: !root.nState.isWindow
        anchors.centerIn: windowBtnRect
        icon: "pip"
        type: IconButton.Text
        label.fill: 0
        inactiveOnColour: hovered ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        stateLayer.opacity: 0
        onClicked: {
            WindowFactory.create();
            root.close();
        }

        label.scale: pressed ? 0.8 : 1
        label.renderType: Text.QtRendering

        Behavior on label.scale {
            Anim {}
        }
    }

    NavPane {
        id: navPane

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large

        nState: nState
        width: Math.min(Tokens.sizes.nexus.maxNavWidth, Math.round(root.width / 3))
    }

    Pages {
        anchors.left: navPane.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: navPane.anchors.margins + anchors.margins
        anchors.margins: Tokens.padding.extraLarge

        nState: nState
    }

    // The password prompt (polkit), when it is this window's: over the page,
    // like the settings' other dialogs
    Item {
        id: polkitHost

        readonly property bool shown: Polkit.active && Polkit.decided && Polkit.host === root

        anchors.fill: parent
        z: 10
        visible: opacity > 0
        opacity: shown ? 1 : 0

        Behavior on opacity {
            Anim {}
        }

        StyledRect {
            anchors.fill: parent
            radius: root.nState.isWindow ? 0 : Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3scrim, 0.32)
        }

        // Nothing under it reacts while it's open
        MouseArea {
            anchors.fill: parent
            enabled: polkitHost.shown
            hoverEnabled: enabled
            onWheel: event => event.accepted = true
        }

        Loader {
            anchors.centerIn: parent
            active: polkitHost.shown
            sourceComponent: PolkitCard {
                scale: 0.92
                Component.onCompleted: {
                    scale = 1;
                    focusField();
                }

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }
        }
    }
}
