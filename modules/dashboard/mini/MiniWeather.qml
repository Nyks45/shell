pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Dashboard > Weather, small (the island's page size): now on the left, the next days on the right
Item {
    id: root

    implicitWidth: Tokens.sizes.dashboard.islandWidth
    implicitHeight: Tokens.sizes.dashboard.islandHeight

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.preferredWidth: 170
            Layout.maximumWidth: 170
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Weather.city || Tr.tr("Weather")
                font: Tokens.font.label.large
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: Weather.icon
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    text: Weather.temp
                    font: Tokens.font.headline.medium
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Weather.description
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            // The details, each with its icon
            GridLayout {
                Layout.topMargin: Tokens.spacing.small
                columns: 2
                rowSpacing: 2
                columnSpacing: Tokens.spacing.small

                Detail {
                    icon: "thermostat"
                    text: Weather.feelsLike
                }

                Detail {
                    icon: "water_drop"
                    text: `${Weather.humidity}%`
                }

                Detail {
                    icon: "air"
                    text: `${Math.round(Weather.windSpeed)} km/h`
                }

                Detail {
                    icon: "wb_twilight"
                    text: Weather.sunrise
                }

                Detail {
                    icon: "bedtime"
                    text: Weather.sunset
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        // The next days
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: Weather.forecast.slice(0, 5)

                StyledRect {
                    id: day

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: Tokens.rounding.large
                    color: index === 0 ? Colours.palette.m3secondaryContainer : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.45)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: day.index === 0 ? Tr.trCtx("Today", "forecast column") : new Date(day.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                            font: Tokens.font.label.medium
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: day.modelData.icon
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.formatTemp(day.modelData.maxTempC, true)
                            font: Tokens.font.label.medium
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.formatTemp(day.modelData.minTempC, true)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                }
            }
        }
    }

    component Detail: RowLayout {
        property string icon
        property string text

        spacing: 2

        MaterialIcon {
            text: parent.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            text: parent.text
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
