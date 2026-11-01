pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A font setting: the current family, shown in itself; clicking opens a
// searchable list of the installed families (each in its own font) below.
ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property string family
    property bool monoOnly
    property bool expanded

    signal picked(family: string)

    readonly property var list: {
        const all = monoOnly ? Fonts.monoFamilies : Fonts.families;
        const q = filter.text.trim().toLowerCase();
        return q ? all.filter(f => f.toLowerCase().includes(q)) : all;
    }

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + Tokens.padding.medium * 2
    clip: true

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    id: label

                    Layout.fillWidth: true
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.subtext
                    text: root.subtext
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            TextMetrics {
                id: familyMetrics

                font: familyText.font
                text: familyText.text
            }

            StyledRect {
                implicitWidth: Math.min(familyMetrics.advanceWidth + Tokens.padding.large + Tokens.padding.medium + Tokens.spacing.small + chevron.implicitWidth + 2, root.width * 0.5)
                implicitHeight: familyText.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                StateLayer {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Colours.palette.m3onSecondaryContainer
                    onClicked: {
                        root.expanded = !root.expanded;
                        if (root.expanded)
                            filter.forceActiveFocus();
                    }
                }

                StyledText {
                    id: familyText

                    anchors.left: parent.left
                    anchors.right: chevron.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.spacing.small
                    text: root.family || Tr.tr("Default")
                    font.family: root.family || Tokens.font.body.small.family
                    font.pointSize: Tokens.font.body.small.pointSize
                    color: Colours.palette.m3onSecondaryContainer
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    id: chevron

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Tokens.padding.medium
                    text: root.expanded ? "expand_less" : "expand_more"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.small
                }
            }
        }

        // The picker
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: Tokens.spacing.small

            SearchBar {
                id: filter

                Layout.fillWidth: true
                placeholderText: Tr.tr("Search fonts")
                font: Tokens.font.body.small
                topPadding: Tokens.padding.medium
                bottomPadding: Tokens.padding.medium
                bg.color: Colours.tPalette.m3surfaceContainerHigh
                Keys.onEscapePressed: root.expanded = false
                onAccepted: {
                    if (root.list.length > 0) {
                        root.picked(root.list[0]);
                        root.expanded = false;
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 260
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainerLow

                VerticalFadeListView {
                    id: listView

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraSmall
                    clip: true
                    model: root.expanded ? root.list : []
                    reuseItems: true

                    delegate: StyledRect {
                        id: entry

                        required property string modelData
                        readonly property bool current: modelData === root.family

                        width: ListView.view.width
                        implicitHeight: entryText.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: current ? Colours.palette.m3tertiaryContainer : "transparent"

                        StateLayer {
                            anchors.fill: parent
                            radius: parent.radius
                            onClicked: {
                                root.picked(entry.modelData);
                                root.expanded = false;
                            }
                        }

                        StyledText {
                            id: entryText

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.padding.medium
                            text: entry.modelData
                            font.family: entry.modelData
                            font.pointSize: Tokens.font.body.medium.pointSize
                            color: entry.current ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.list.length === 0
                    text: Tr.tr("No fonts match")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
