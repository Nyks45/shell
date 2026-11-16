import "dash"
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.services

GridLayout {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    rowSpacing: Tokens.spacing.small
    columnSpacing: Tokens.spacing.small

    // The overview, compact: weather and the account on top, the calendar under them. The time,
    // media and the gauges have their own places (the island's pill and its pages).
    Rect {
        Layout.row: 0
        Layout.column: 0
        Layout.preferredWidth: Tokens.sizes.dashboard.weatherWidth
        Layout.preferredHeight: Math.max(weather.implicitHeight, user.implicitHeight)

        radius: Tokens.rounding.extraLarge

        SmallWeather {
            id: weather
        }
    }

    Rect {
        Layout.row: 0
        Layout.column: 1
        Layout.preferredWidth: Tokens.sizes.dashboard.userWidth
        Layout.fillHeight: true

        radius: Tokens.rounding.extraLarge

        User {
            id: user

            screenState: root.screenState
            facePicker: root.facePicker
        }
    }

    Rect {
        Layout.row: 1
        Layout.column: 0
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.preferredHeight: calendar.implicitHeight

        radius: Tokens.rounding.extraLarge

        Calendar {
            id: calendar

            screenState: root.screenState
        }
    }

    component Rect: StyledRect {
        color: Colours.tPalette.m3surfaceContainer
    }
}
