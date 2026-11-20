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
// floating searchable list of the installed families (each in its own font).
ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property string family
    property bool monoOnly
    property alias expanded: popup.expanded
    property string query

    readonly property var list: {
        const all = monoOnly ? Fonts.monoFamilies : Fonts.families;
        const q = query.trim().toLowerCase();
        return q ? all.filter(f => f.toLowerCase().includes(q)) : all;
    }

    signal picked(family: string)

    onVisibleChanged: if (!visible)
        popup.expanded = false

    Layout.fillWidth: true
    implicitHeight: headerRow.implicitHeight + Tokens.padding.medium * 2

    FontMetrics {
        id: entryMetrics

        font: Tokens.font.body.small
    }

    RowLayout {
        id: headerRow

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
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
                wrapMode: Text.WordWrap
            }
        }

        TextMetrics {
            id: familyMetrics

            font: familyText.font
            text: familyText.text
        }

        StyledRect {
            id: pill

            implicitWidth: Math.min(familyMetrics.advanceWidth + Tokens.padding.large + Tokens.padding.medium + Tokens.spacing.small + chevron.implicitWidth + 2, root.width * 0.5)
            implicitHeight: familyText.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            color: Colours.palette.m3secondaryContainer

            onVisibleChanged: if (!visible)
                popup.expanded = false

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                color: Colours.palette.m3onSecondaryContainer
                onClicked: {
                    popup.expanded = !popup.expanded;
                    if (popup.expanded)
                        Qt.callLater(() => (popup.item as Item)?.forceActiveFocus());
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
                text: popup.expanded ? "expand_less" : "expand_more"
                color: Colours.palette.m3onSecondaryContainer
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    FloatingPopup {
        id: popup

        readonly property real rowH: Math.ceil(entryMetrics.height) + Tokens.padding.small * 2
        readonly property real searchH: Math.ceil(entryMetrics.height) + Tokens.padding.small * 2
        readonly property real listH: root.list.length > 0 ? Math.min(210, root.list.length * rowH + Math.max(0, root.list.length - 1) * 2) : 48

        attachTo: pill
        ownArea: pill
        contentWidth: 256
        contentHeight: searchH + Tokens.spacing.small + listH
        maxHeight: 280
        onExpandedChanged: if (expanded)
            root.query = ""
        onActiveChanged: if (!active)
            root.query = ""

        content: Component {
            ColumnLayout {
                id: popupCol

                function focusSearch(): void {
                    filter.forceActiveFocus();
                }

                spacing: Tokens.spacing.small

                onActiveFocusChanged: if (activeFocus)
                    focusSearch()

                SearchBar {
                    id: filter

                    Layout.fillWidth: true
                    implicitHeight: popup.searchH
                    placeholderText: Tr.tr("Search fonts")
                    font: Tokens.font.body.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small
                    bg.color: Colours.tPalette.m3surfaceContainerLowest
                    bg.border.width: 1
                    bg.border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: popup.expanded = false
                    onAccepted: {
                        if (root.list.length > 0) {
                            root.picked(root.list[0]);
                            popup.expanded = false;
                        }
                    }

                    Connections {
                        function onQueryChanged(): void {
                            if (filter.text !== root.query)
                                filter.text = root.query;
                        }

                        target: root
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    VerticalFadeListView {
                        id: listView

                        anchors.fill: parent
                        clip: true
                        fadeAmount: 0.08
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.list
                        reuseItems: true

                        delegate: StyledRect {
                            id: entry

                            required property string modelData
                            readonly property bool current: modelData === root.family

                            width: ListView.view.width
                            implicitHeight: popup.rowH
                            radius: height / 2
                            color: current ? Colours.palette.m3secondaryContainer : "transparent"

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                color: entry.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                onClicked: {
                                    root.picked(entry.modelData);
                                    popup.expanded = false;
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
                                font.pointSize: Tokens.font.body.small.pointSize
                                color: entry.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
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
}
