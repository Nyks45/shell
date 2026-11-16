pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Dashboard > overview, small (the island's page size): the date, the weather now and who's
// signed in, over this week with today marked
Item {
    id: root

    readonly property date now: Time.date
    // This week, Monday first
    readonly property var week: {
        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const monday = new Date(d);
        monday.setDate(d.getDate() - ((d.getDay() + 6) % 7));
        return Array.from({
            length: 7
        }, (_, i) => new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i));
    }

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            // The date
            Card {
                Layout.preferredWidth: 110

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.now.toLocaleDateString(Qt.locale(), "dddd")
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.now.getDate()
                        font: Tokens.font.headline.medium
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.now.toLocaleDateString(Qt.locale(), "MMMM")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }

            // The weather now
            Card {
                Layout.fillWidth: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: Weather.icon
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.large
                    }

                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            text: Weather.temp
                            font: Tokens.font.title.large
                        }

                        StyledText {
                            text: Weather.description
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            // Who's signed in
            Card {
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.small

                    ClipRect {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: face.status !== Image.Ready
                            text: "person"
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        Image {
                            id: face

                            anchors.fill: parent
                            source: Paths.faceSource ? `file://${Paths.faceSource}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 80
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: SysInfo.user
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("Up %1").arg(SysInfo.uptimeShort || SysInfo.uptime)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // This week
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: root.week

                StyledRect {
                    id: dayCell

                    required property var modelData
                    readonly property bool today: modelData.toDateString() === root.now.toDateString()

                    Layout.fillWidth: true
                    implicitHeight: dayCol.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.medium
                    color: today ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

                    ColumnLayout {
                        id: dayCol

                        anchors.centerIn: parent
                        spacing: 0

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: dayCell.modelData.toLocaleDateString(Qt.locale(), "ddd")
                            color: dayCell.today ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: dayCell.modelData.getDate()
                            color: dayCell.today ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            font: Tokens.font.label.large
                        }
                    }
                }
            }
        }
    }

    component Card: StyledRect {
        Layout.fillHeight: true
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh
    }
}
