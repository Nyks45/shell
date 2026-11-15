pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Nebula's colour roles, taken from the shell's own scheme (services/Colours.qml) instead of
// Nebula's matugen file: one scheme for everything.
Singleton {
    readonly property bool isDark: !Colours.light
    readonly property color primary: Colours.palette.m3primary
    readonly property color textOnPrimary: Colours.palette.m3onPrimary
    readonly property color primaryContainer: Colours.palette.m3primaryContainer
    readonly property color textOnPrimaryContainer: Colours.palette.m3onPrimaryContainer
    readonly property color secondary: Colours.palette.m3secondary
    readonly property color textOnSecondary: Colours.palette.m3onSecondary
    readonly property color secondaryContainer: Colours.palette.m3secondaryContainer
    readonly property color textOnSecondaryContainer: Colours.palette.m3onSecondaryContainer
    readonly property color tertiary: Colours.palette.m3tertiary
    readonly property color textOnTertiary: Colours.palette.m3onTertiary
    // The shell's schemes make the tertiary container a light pastel in dark mode (Nebula's
    // matugen makes it dark): there it's put at the primary container's depth, so tertiary glass
    // (calendar, notes...) stays deep and see-through like Nebula's
    readonly property bool lightTertiary: isDark && Colours.palette.m3tertiaryContainer.hslLightness > 0.45
    readonly property color tertiaryContainer: lightTertiary ? Qt.hsla(Colours.palette.m3tertiary.hslHue, Math.min(0.45, Colours.palette.m3tertiary.hslSaturation), Colours.palette.m3primaryContainer.hslLightness, 1) : Colours.palette.m3tertiaryContainer
    readonly property color textOnTertiaryContainer: lightTertiary ? Qt.hsla(Colours.palette.m3tertiary.hslHue, Math.min(0.6, Colours.palette.m3tertiary.hslSaturation), 0.9, 1) : Colours.palette.m3onTertiaryContainer
    readonly property color errorColor: Colours.palette.m3error
    readonly property color textOnError: Colours.palette.m3onError
    readonly property color errorContainer: Colours.palette.m3errorContainer
    readonly property color textOnErrorContainer: Colours.palette.m3onErrorContainer
    readonly property color surface: Colours.palette.m3surface
    readonly property color surfaceContainerLowest: Colours.palette.m3surfaceContainerLowest
    readonly property color surfaceContainerLow: Colours.palette.m3surfaceContainerLow
    readonly property color surfaceContainer: Colours.palette.m3surfaceContainer
    readonly property color surfaceContainerHigh: Colours.palette.m3surfaceContainerHigh
    readonly property color surfaceContainerHighest: Colours.palette.m3surfaceContainerHighest
    readonly property color textOnSurface: Colours.palette.m3onSurface
    readonly property color textOnSurfaceVariant: Colours.palette.m3onSurfaceVariant
    readonly property color outline: Colours.palette.m3outline
    readonly property color outlineVariant: Colours.palette.m3outlineVariant
    readonly property color shadow: Colours.palette.m3shadow
    readonly property color scrim: Colours.palette.m3scrim
    readonly property color inverseSurface: Colours.palette.m3inverseSurface
    readonly property color inverseOnSurface: Colours.palette.m3inverseOnSurface
    readonly property color inversePrimary: Colours.palette.m3inversePrimary
}
