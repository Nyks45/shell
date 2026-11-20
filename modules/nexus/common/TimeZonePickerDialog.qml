pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services

// Searchable time-zone & city picker modal built on DialogRowButton.
DialogRowButton {
    id: root

    property Item hostFlickable: null
    // [{ id, city, region, offsetMin, search }]
    property var zones: []
    property string currentZone: ""
    property string searchQuery: ""
    property double openedAtMs: Date.now()

    signal picked(tz: string)

    function formatOffset(offsetMin: int): string {
        if (offsetMin === 0)
            return "UTC";
        const sign = offsetMin > 0 ? "+" : "-";
        const abs = Math.abs(offsetMin);
        const hh = Math.floor(abs / 60);
        const mm = abs % 60;
        return mm ? `UTC${sign}${hh}:${String(mm).padStart(2, "0")}` : `UTC${sign}${hh}`;
    }

    function formatLocalTime(offsetMin: int): string {
        const d = new Date(root.openedAtMs + offsetMin * 60000);
        const h24 = d.getUTCHours();
        const min = String(d.getUTCMinutes()).padStart(2, "0");
        if (Units.twelveHourClock) {
            const ampm = h24 >= 12 ? "PM" : "AM";
            const h12 = h24 % 12 || 12;
            return `${h12}:${min} ${ampm}`;
        }
        return `${String(h24).padStart(2, "0")}:${min}`;
    }

    function openPicker(): void {
        searchQuery = "";
        openedAtMs = Date.now();
        open = true;
    }

    visible: false
    rootParent: hostFlickable
    openWidth: Math.min((hostFlickable?.width ?? 600) * 0.85, 480)
    openHeight: Math.min((hostFlickable?.height ?? 600) * 0.85, 560)
    icon: "public"
    label: ""
    header: Tr.tr("Choose a time zone")
    acceptLabel: ""
    showAccept: false
    showCancel: true

    content: Component {
        ColumnLayout {
            id: modalCol

            readonly property var filtered: {
                const q = root.searchQuery.trim().toLowerCase();
                if (!q)
                    return root.zones;
                return root.zones.filter(z => z.search.includes(q));
            }

            spacing: Tokens.spacing.small

            StyledTextField {
                id: searchField

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.medium
                leadingIcon: "search"
                verticalPadding: Tokens.padding.small
                floatingPlaceholder: false
                placeholderText: Tr.tr("Search city, country or region…")
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
                onAccepted: {
                    if (modalCol.filtered.length > 0) {
                        root.open = false;
                        root.picked(modalCol.filtered[0].id);
                    }
                }
                Keys.onEscapePressed: root.open = false
                Component.onCompleted: forceActiveFocus()
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: Tokens.spacing.small

                ListView {
                    id: tzView

                    anchors.fill: parent
                    clip: true
                    spacing: Tokens.spacing.extraSmall
                    model: modalCol.filtered
                    Component.onCompleted: {
                        const idx = modalCol.filtered.findIndex(z => z.id === root.currentZone);
                        if (idx >= 0)
                            positionViewAtIndex(idx, ListView.Center);
                    }

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: tzView
                    }

                    delegate: StyledRect {
                        id: tzRect

                        required property var modelData
                        readonly property bool isCurrent: modelData.id === root.currentZone

                        width: tzView.width
                        implicitHeight: 52
                        radius: Tokens.rounding.medium
                        color: isCurrent ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        StateLayer {
                            anchors.fill: parent
                            radius: tzRect.radius
                            color: tzRect.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            onClicked: {
                                root.open = false;
                                root.picked(tzRect.modelData.id);
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: tzRect.modelData.city
                                    font: Tokens.font.body.small
                                    color: tzRect.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: tzRect.modelData.region
                                    font: Tokens.font.label.small
                                    color: tzRect.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                    elide: Text.ElideRight
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: root.formatLocalTime(tzRect.modelData.offsetMin)
                                    font: Tokens.font.label.medium
                                    color: tzRect.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: root.formatOffset(tzRect.modelData.offsetMin)
                                    font: Tokens.font.label.small
                                    color: tzRect.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.large * 2
                    visible: modalCol.filtered.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Tr.tr("No matching time zones")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
