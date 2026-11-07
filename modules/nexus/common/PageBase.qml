pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    required property string title
    required property NexusState nState
    property bool isSubPage
    readonly property int cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)
    readonly property alias flickable: flickable

    default property Item contentChild

    spacing: Tokens.spacing.extraLargeIncreased

    // Search: scroll to the row the search picked and flash it. The row is the
    // first visible item (in reading order) whose label/text is the setting's,
    // after the section header it sits under when the label is used twice.
    function findRow(item: Item, text: string, section: string, state: var): Item {
        if (!item || !item.visible)
            return null;
        if (item.isSectionHeader === true) {
            state.section = item.text;
            return null;
        }
        const own = typeof item.label === "string" ? item.label : typeof item.text === "string" ? item.text : null;
        if (own === text && (!section || state.section === section) && item !== root.contentChild)
            return item;
        for (const child of item.children) {
            const hit = findRow(child, text, section, state);
            if (hit)
                return hit;
        }
        return null;
    }

    function showHighlight(): void {
        const h = nState.highlight;
        if (!h || (root.StackView.index >= 0 ? root.StackView.index : 0) !== h.depth)
            return;
        // Labels used twice: try within the section, then anywhere
        const row = findRow(root.contentChild, h.text, h.section, {
            section: ""
        }) ?? findRow(root.contentChild, h.text, "", {
            section: ""
        });
        nState.highlight = null;
        if (!row)
            return;

        const y = row.mapToItem(flickable.contentItem, 0, 0).y;
        const maxY = Math.max(0, flickable.contentHeight - flickable.height + flickable.bottomMargin);
        scrollAnim.to = Math.max(-flickable.topMargin, Math.min(maxY, y - flickable.height / 3));
        scrollAnim.restart();
        flashComp.createObject(row);
    }

    Component.onCompleted: highlightTimer.start()

    // After the page's fade-in and layout
    Timer {
        id: highlightTimer

        interval: 350
        onTriggered: root.showHighlight()
    }

    Connections {
        function onHighlightRequested(): void {
            highlightTimer.restart();
        }

        target: root.nState
    }

    Anim {
        id: scrollAnim

        target: flickable
        property: "contentY"
        type: Anim.DefaultSpatial
    }

    Component {
        id: flashComp

        StyledRect {
            id: flash

            anchors.fill: parent
            z: 10
            radius: (parent as StyledRect)?.radius ?? Tokens.rounding.small
            topLeftRadius: (parent as StyledRect)?.topLeftRadius ?? radius
            topRightRadius: (parent as StyledRect)?.topRightRadius ?? radius
            bottomLeftRadius: (parent as StyledRect)?.bottomLeftRadius ?? radius
            bottomRightRadius: (parent as StyledRect)?.bottomRightRadius ?? radius
            color: Colours.palette.m3primary
            opacity: 0

            SequentialAnimation on opacity {
                running: true

                PauseAnimation {
                    duration: 200
                }
                Anim {
                    to: 0.22
                    type: Anim.DefaultEffects
                }
                Anim {
                    to: 0.06
                    type: Anim.SlowEffects
                }
                Anim {
                    to: 0.22
                    type: Anim.DefaultEffects
                }
                Anim {
                    to: 0
                    type: Anim.SlowEffects
                }
                ScriptAction {
                    script: flash.destroy()
                }
            }
        }
    }

    MouseArea { // Prevent clicks from reaching flickable
        z: 1
        implicitWidth: header.implicitWidth
        implicitHeight: header.implicitHeight - Layout.bottomMargin
        Layout.bottomMargin: -flickable.topMargin // Extra height to block clicks on flickable top margin
        onClicked: focus = true

        RowLayout {
            id: header

            spacing: Tokens.spacing.largeIncreased

            Loader {
                visible: active
                active: root.isSubPage
                asynchronous: true
                sourceComponent: IconButton {
                    icon: "arrow_back"
                    font: Tokens.font.icon.medium
                    type: IconButton.Tonal
                    isRound: true
                    inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant
                    onClicked: root.nState.back()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font: Tokens.font.title.large
                elide: Text.ElideRight
            }
        }
    }

    VerticalFadeFlickable {
        id: flickable

        Layout.fillWidth: true
        Layout.fillHeight: true

        Layout.topMargin: -topMargin
        topMargin: Tokens.padding.large
        bottomMargin: Tokens.padding.extraLarge

        contentHeight: root.contentChild?.implicitHeight ?? 0
        contentItem.children: [root.contentChild]

        TapHandler {
            onTapped: flickable.focus = true
        }
    }
}
