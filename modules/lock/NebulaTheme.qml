pragma Singleton

import QtQuick
import Caelestia.Config
import qs.services

QtObject {
    component ColorTokens: QtObject {
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
        readonly property color tertiaryContainer: Colours.palette.m3tertiaryContainer
        readonly property color textOnTertiaryContainer: Colours.palette.m3onTertiaryContainer
        readonly property color surface: Colours.palette.m3surface
        readonly property color textOnSurface: Colours.palette.m3onSurface
        readonly property color textOnSurfaceVariant: Colours.palette.m3onSurfaceVariant
        readonly property color surfaceContainer: Colours.palette.m3surfaceContainer
        readonly property color surfaceContainerHigh: Colours.palette.m3surfaceContainerHigh
        readonly property color surfaceContainerHighest: Colours.palette.m3surfaceContainerHighest
        readonly property color inversePrimary: Colours.palette.m3inversePrimary
        readonly property color errorColor: Colours.palette.m3error
        readonly property color errorContainer: Colours.palette.m3errorContainer
        readonly property color textOnErrorContainer: Colours.palette.m3onErrorContainer
    }
    readonly property ColorTokens colors: ColorTokens {}

    component GalaxyTokens: QtObject {
        readonly property int stars: 160
        readonly property real starFaint: 0.25
        readonly property real starBright: 0.6
    }
    readonly property GalaxyTokens galaxy: GalaxyTokens {}

    component GlassTokens: QtObject {
        readonly property real tint: 0.72
        readonly property real topLight: 0.08
    }
    readonly property GlassTokens glass: GlassTokens {}

    component MediaTokens: QtObject {
        readonly property int artBlur: 28
        readonly property real artOpacity: 0.55
        readonly property int artFade: 800
        readonly property int artSourceSize: 256
    }
    readonly property MediaTokens media: MediaTokens {}

    component BatteryRingTokens: QtObject {
        readonly property int size: 50
        readonly property int thickness: 3
        readonly property real trackOpacity: 0.28
        readonly property real lowLevel: 0.2
    }
    readonly property BatteryRingTokens batteryRing: BatteryRingTokens {}

    component ButtonTokens: QtObject {
        readonly property int size: 40
        readonly property int iconSize: 20
        readonly property int playSize: 56
        readonly property int playIconSize: 28
    }
    readonly property ButtonTokens button: ButtonTokens {}

    component LockTokens: QtObject {
        readonly property color space: "#05050f"
        readonly property color star: "#e9e4ff"
        readonly property int twinklers: 18
        readonly property int ringDots: 90
        readonly property real ringTilt: 0.32
        readonly property real backdropDim: 0.44
        readonly property real surfaceTint: 0.94
        readonly property real blurSource: 0.5
        readonly property int blurMax: 28
        readonly property int openDuration: 3400
        readonly property int closeDuration: 1500
        readonly property real centerOvershoot: 1.2
        readonly property real wingOvershoot: 1.12
        readonly property real foldOvershoot: 1.3
        readonly property int holeSize: 160
        readonly property int clockSize: 250
        readonly property int musicWidth: 196
        readonly property int musicHeight: 236
        readonly property int notificationWidth: 100
        readonly property int notificationHeight: 122
        readonly property real orbitX: 0.3
        readonly property real orbitY: 0.3
        readonly property int orbitPeriod: 150
        readonly property real depthScale: 0.14
        readonly property real depthOpacity: 0.35
        readonly property int bob: 6
        readonly property int bobPeriod: 7
        readonly property int activeClockSize: 340
        readonly property int activeMusicWidth: 320
        readonly property int activeMusicHeight: 480
        readonly property int activeNotificationWidth: 340
        readonly property int activeNotificationHeight: 84
        readonly property int notificationGap: 14
        readonly property int sideGap: 48
        readonly property int modeDuration: 1400
        readonly property int idleTimeout: 15000
        readonly property real innerOrbitX: 0.19
        readonly property real innerOrbitY: 0.14
        readonly property int innerPeriod: 80
        readonly property int planetSize: 132
        readonly property int moonSize: 96
        readonly property int batterySize: 96
        readonly property real pulseGain: 0.45
        readonly property int visualizerBars: 24
        readonly property int dotSize: 7
        readonly property int dotMax: 14
        readonly property real holePulse: 0.12
        readonly property int statsWidth: 540
        readonly property int statsHeight: 256
        readonly property int statsGap: 28
        readonly property int rowOffset: 70
        readonly property int bubbleSize: 84
        readonly property int inputWidth: 400
        readonly property int inputHeight: 56
        readonly property int inputGap: 28
        readonly property int rowSpacing: 130
        readonly property int eqHeight: 170
        readonly property int maxNotifications: 3
        readonly property int maxDots: 14
        readonly property real spiralTurn: 2.8
        readonly property real wingStartScale: 0.3
        readonly property real centerHeight: 0.42
        readonly property int bootLoadingMinMs: 1100
        readonly property int bootLoadingMaxMs: 1800
    }
    readonly property LockTokens lock: LockTokens {}

    component RadiusTokens: QtObject {
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
        readonly property int full: 999
    }
    readonly property RadiusTokens radius: RadiusTokens {}

    component FontTokens: QtObject {
        readonly property string family: GlobalConfig.appearance.font.body.family
        readonly property string icons: GlobalConfig.appearance.font.icon.family
        readonly property string mono: GlobalConfig.appearance.font.mono.family
        readonly property int small: 12
        readonly property int normal: 14
        readonly property int large: 16
        readonly property int clock: 20
    }
    readonly property FontTokens font: FontTokens {}

    component AnimTokens: QtObject {
        readonly property real scale: Tokens.anim.durations.scale > 0 ? Tokens.anim.durations.scale : 1.0
        readonly property int fast: Math.round(150 * scale)
        readonly property int medium: Math.round(300 * scale)
        readonly property int slow: Math.round(500 * scale)
        readonly property real overshoot: 1.2
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    }
    readonly property AnimTokens anim: AnimTokens {}
}
