pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Blobs
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property Item rootParent
    required property string icon
    required property string label
    property string subtext
    required property string header
    required property Component content
    required property string acceptLabel
    property bool acceptAllowed: true
    property bool showAccept: true
    property bool showCancel: true
    property bool separateContent
    property int horizontalContentMargin

    property real openWidth: Math.min((rootParent?.width ?? 0) * 0.8, Tokens.sizes.nexus.maxDialogWidth)
    property real openHeight: Math.min((rootParent?.height ?? 0) * 0.8, Tokens.sizes.nexus.maxDialogHeight)
    property bool open
    // Its place in a group of rows (rounded corners like ConnectedRect's):
    // where it sits among the visible rows of its column (Rows) unless set
    property bool groupStart
    readonly property int _rowsId: Rows.nextId()
    readonly property bool isGroupRow: true
    readonly property bool headlessModal: !root.visible
    readonly property bool transitioning: openTransition.running || closeTransition.running
    property bool first: headlessModal ? true : Rows.isFirst(root)
    property bool last: headlessModal ? true : Rows.isLast(root)
    readonly property real gap: headlessModal ? 0 : Rows.gapAbove(root)

    signal accepted
    signal cancelled

    function reparentTo(targetParent: Item): void {
        if (!targetParent || dialogWrapper.parent === targetParent)
            return;
        if (root.headlessModal) {
            dialogWrapper.parent = targetParent;
            if (targetParent === root.rootParent) {
                dialogWrapper.x = (targetParent.width - root.openWidth) / 2;
                dialogWrapper.y = (targetParent.height - root.openHeight) / 2;
            }
            return;
        }
        const pos = dialogWrapper.mapToItem(targetParent, 0, 0);
        dialogWrapper.parent = targetParent;
        dialogWrapper.x = pos.x;
        dialogWrapper.y = pos.y;
    }

    Component.onCompleted: if (!root.headlessModal) Rows.bump(root)
    Component.onDestruction: if (!root.headlessModal) Rows.onRowDestroyed(root)

    Layout.fillWidth: true
    Layout.topMargin: !root.headlessModal && root.groupStart && !Rows.isAtTop(root) ? Math.max(0, Tokens.spacing.largeIncreased - root.gap) : 0
    implicitHeight: Math.ceil(openButton.implicitHeight)
    z: open || transitioning ? 2 : 0

    BlobGroup {
        id: blobGroup

        color: root.open || root.headlessModal ? Colours.palette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainer

        Behavior on color {
            CAnim {}
        }
    }

    // Closed card background clipped inside flat seam edges (same seam-free pattern
    // as ConnectedRect); BlobRect takes over only when opening or open.
    Item {
        id: closedBgClip

        readonly property bool bridgeAbove: !root.first && root.gap > 0

        z: 0
        clip: true
        visible: !root.headlessModal && !root.open && !root.transitioning
        x: 0
        y: bridgeAbove ? -root.gap : 0
        width: root.width
        height: root.height + (bridgeAbove ? root.gap : 0)

        StyledRect {
            anchors.fill: parent
            anchors.topMargin: !root.first ? -2 : 0
            anchors.bottomMargin: !root.last ? -2 : 0
            color: Colours.tPalette.m3surfaceContainer
            topLeftRadius: root.first ? Tokens.rounding.extraLarge : 0
            topRightRadius: root.first ? Tokens.rounding.extraLarge : 0
            bottomLeftRadius: root.last ? Tokens.rounding.extraLarge : 0
            bottomRightRadius: root.last ? Tokens.rounding.extraLarge : 0
        }
    }

    MouseArea {
        id: backdrop

        anchors.fill: parent
        parent: root.open ? root.rootParent : root
        enabled: false
        hoverEnabled: enabled
        // A click outside is a cancel (callers clear their state on cancelled)
        onClicked: {
            root.cancelled();
            root.open = false;
        }
    }

    Item {
        id: dialogWrapper

        z: 1
        x: root.headlessModal && root.rootParent ? (root.rootParent.width - root.openWidth) / 2 : 0
        y: root.headlessModal && root.rootParent ? (root.rootParent.height - root.openHeight) / 2 : 0
        width: root.headlessModal ? root.openWidth : root.width
        height: root.headlessModal ? root.openHeight : openButton.implicitHeight
        opacity: root.headlessModal ? 0 : 1
        scale: root.headlessModal ? 0.92 : 1

        states: State {
            name: "open"
            when: root.open

            PropertyChanges {
                backdrop.enabled: true
                elevation.opacity: 1
                openButton.opacity: 0
                dialogContent.opacity: 1
                dialogWrapper.opacity: 1
                dialogWrapper.scale: 1
                dialogBg.radius: root.Tokens.rounding.extraLargeIncreased
                dialogBg.topLeftRadius: root.Tokens.rounding.extraLargeIncreased
                dialogBg.topRightRadius: root.Tokens.rounding.extraLargeIncreased
                dialogBg.bottomLeftRadius: root.Tokens.rounding.extraLargeIncreased
                dialogBg.bottomRightRadius: root.Tokens.rounding.extraLargeIncreased
                dialogWrapper.x: (root.rootParent.width - root.openWidth) / 2
                dialogWrapper.y: (root.rootParent.height - root.openHeight) / 2
                dialogWrapper.width: root.openWidth
                dialogWrapper.height: root.openHeight
            }
        }

        transitions: [
            Transition {
                id: openTransition

                from: ""
                to: "open"

                SequentialAnimation {
                    ScriptAction {
                        script: root.reparentTo(root.rootParent)
                    }
                    Anim {
                        properties: "x,y"
                    }
                }
                PropertyAction {
                    property: "enabled"
                }
                Anim {
                    properties: "opacity,scale,radius,topLeftRadius,topRightRadius,bottomLeftRadius,bottomRightRadius"
                    type: Anim.DefaultEffects
                }
                Anim {
                    properties: "width,height"
                }
            },
            Transition {
                id: closeTransition

                from: "open"
                to: ""

                SequentialAnimation {
                    ScriptAction {
                        script: if (!root.headlessModal) root.reparentTo(root)
                    }
                    ParallelAnimation {
                        Anim {
                            properties: "x,y"
                        }
                        PropertyAction {
                            property: "enabled"
                        }
                        Anim {
                            properties: "opacity,scale,radius,topLeftRadius,topRightRadius,bottomLeftRadius,bottomRightRadius"
                            type: Anim.DefaultEffects
                        }
                        Anim {
                            properties: "width,height"
                        }
                    }
                    ScriptAction {
                        // Headless modals are invisible items, so keep dialogWrapper on rootParent
                        // until the fade/scale close finishes, then park it back if still closed.
                        script: if (root.headlessModal && !root.open) root.reparentTo(root)
                    }
                }
            }
        ]

        Elevation {
            id: elevation

            transform: Matrix4x4 {
                matrix: dialogBg.deformMatrix
            }

            anchors.fill: parent
            radius: dialogBg.radius
            bottomLeftRadius: dialogBg.bottomLeftRadius
            bottomRightRadius: dialogBg.bottomRightRadius
            level: 4
            opacity: 0
        }

        BlobRect {
            id: dialogBg

            visible: root.headlessModal || root.open || root.transitioning
            anchors.fill: parent

            deformScale: !root.headlessModal && (root.open || root.transitioning) ? 0.00005 : 0
            group: blobGroup
            opacity: blobGroup.color.a

            radius: root.headlessModal ? Tokens.rounding.extraLargeIncreased : 0
            topLeftRadius: root.headlessModal ? Tokens.rounding.extraLargeIncreased : (root.first ? Tokens.rounding.extraLarge : 0)
            topRightRadius: root.headlessModal ? Tokens.rounding.extraLargeIncreased : (root.first ? Tokens.rounding.extraLarge : 0)
            bottomLeftRadius: root.headlessModal ? Tokens.rounding.extraLargeIncreased : (root.last ? Tokens.rounding.extraLarge : 0)
            bottomRightRadius: root.headlessModal ? Tokens.rounding.extraLargeIncreased : (root.last ? Tokens.rounding.extraLarge : 0)
        }

        RowButton {
            id: openButton

            visible: !root.headlessModal

            transform: Matrix4x4 {
                matrix: dialogBg.deformMatrix
            }

            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(implicitHeight, parent.height) // Clamp to parent height due to overshoot anim
            fillColour: "transparent"

            first: root.first
            last: root.last
            icon: root.icon
            text: root.label
            subtext: root.subtext
            onClicked: root.open = true
        }

        Loader {
            id: dialogContent

            transform: Matrix4x4 {
                matrix: dialogBg.deformMatrix
            }

            anchors.fill: parent

            opacity: 0
            active: opacity > 0
            asynchronous: true

            sourceComponent: MouseArea {
                onWheel: event => event.accepted = true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraLarge
                    anchors.bottomMargin: Tokens.padding.largeIncreased
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.header
                        font: Tokens.font.title.builders.large.weight(Font.Normal).build()
                        wrapMode: Text.WordWrap
                    }

                    Loader {
                        Layout.topMargin: Tokens.spacing.medium
                        Layout.fillWidth: true
                        active: root.separateContent
                        sourceComponent: StyledRect {
                            implicitHeight: 1
                            color: Colours.palette.m3outline
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: root.horizontalContentMargin
                        Layout.rightMargin: root.horizontalContentMargin
                        sourceComponent: root.content
                    }

                    Loader {
                        Layout.bottomMargin: Tokens.spacing.medium
                        Layout.fillWidth: true
                        active: root.separateContent
                        sourceComponent: StyledRect {
                            implicitHeight: 1
                            color: Colours.palette.m3outline
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.extraSmall

                        TextButton {
                            visible: root.showCancel
                            type: TextButton.Text
                            isRound: true
                            horizontalPadding: Tokens.padding.largeIncreased
                            verticalPadding: Tokens.padding.medium
                            text: Tr.trCtx("Cancel", "button")
                            onClicked: {
                                root.cancelled();
                                root.open = false;
                            }
                        }

                        TextButton {
                            visible: root.showAccept
                            type: TextButton.Text
                            isRound: true
                            horizontalPadding: Tokens.padding.largeIncreased
                            verticalPadding: Tokens.padding.medium
                            disabled: !root.acceptAllowed
                            text: root.acceptLabel
                            onClicked: {
                                root.accepted();
                                root.open = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
