pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Every drive as a card (its partition layout and health) that unfolds in
// place: partitions, free space, health, actions (DriveDetails). On the
// Storage page; a partition opens its own page (sub-page 1).
ColumnLayout {
    id: root

    required property NexusState nState
    // The page's scroll area: dialogs open over it
    required property Item flickable
    // Unfolded drives (by id)
    property var unfolded: ({})

    function toggle(id: string): void {
        const u = Object.assign({}, unfolded);
        u[id] = !u[id];
        unfolded = u;
    }

    function healthText(h: var): string {
        if (!h)
            return "";
        const s = h.status === "failing" ? Tr.tr("Failing") : h.status === "warning" ? Tr.tr("Check it") : Tr.tr("Healthy");
        return h.temperature !== null && h.temperature !== undefined ? `${s} · ${h.temperature} °C` : s;
    }

    spacing: Tokens.spacing.extraSmall / 2

    Component.onCompleted: Disks.open()
    Component.onDestruction: Disks.close()

    StyledText {
        visible: !Disks.loaded
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.largeIncreased
        text: Tr.tr("Reading the drives…")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Repeater {
        id: driveList

        model: Disks.drives

        ConnectedRect {
            id: card

            required property var modelData
            required property int index
            readonly property var h: modelData.health
            readonly property bool open: !!root.unfolded[modelData.id]

            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: cardLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                // The header: click to unfold or fold
                Item {
                    Layout.fillWidth: true
                    implicitHeight: header.implicitHeight

                    StateLayer {
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.small
                        onClicked: root.toggle(card.modelData.id)
                    }

                    RowLayout {
                        id: header

                        anchors.fill: parent
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: Disks.driveIcon(card.modelData)
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: card.modelData.model || card.modelData.device
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: [Disks.driveKind(card.modelData), Disks.human(card.modelData.size), card.modelData.device, card.modelData.system ? Tr.tr("system drive") : ""].filter(x => x).join(" · ")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }
                        }

                        // Health: green / amber / red
                        StyledRect {
                            visible: !!card.h
                            implicitWidth: healthRow.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: healthRow.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.full
                            color: card.h?.status === "failing" ? Colours.palette.m3errorContainer : card.h?.status === "warning" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer

                            RowLayout {
                                id: healthRow

                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: card.h?.status === "good" ? "check_circle" : "warning"
                                    color: card.h?.status === "failing" ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                                    fontStyle: Tokens.font.icon.small
                                }

                                StyledText {
                                    text: root.healthText(card.h)
                                    color: card.h?.status === "failing" ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                                    font: Tokens.font.label.medium
                                }
                            }
                        }

                        MaterialIcon {
                            text: card.open ? "expand_less" : "expand_more"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }
                    }
                }

                PartitionMap {
                    Layout.fillWidth: true
                    visible: !card.open
                    drive: card.modelData
                }

                Loader {
                    Layout.fillWidth: true
                    active: card.open
                    visible: active
                    sourceComponent: DriveDetails {
                        drive: card.modelData
                        nState: root.nState
                        flickable: root.flickable
                    }
                }
            }
        }
    }
}
