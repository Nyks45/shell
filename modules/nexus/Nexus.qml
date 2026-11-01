pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

Item {
    id: root

    readonly property NexusState nState: NexusState {
        id: nState

        onClose: root.close()
    }
    property color blobColour: Colours.tPalette.m3surfaceContainerLow

    signal close

    implicitWidth: Math.round(implicitHeight * Tokens.sizes.nexus.ratio)
    implicitHeight: Math.round(nState.screen.height * Tokens.sizes.nexus.heightMult)

    Behavior on blobColour {
        CAnim {}
    }

    TapHandler {
        onTapped: root.focus = true
    }

    // The mouse's back button: up one sub-page (or out of the search)
    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: {
            if (root.nState.subPageIdxStack.length > 0)
                root.nState.closeSubPage();
            else if (root.nState.searchOpen)
                root.nState.searchOpen = false;
        }
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
}
