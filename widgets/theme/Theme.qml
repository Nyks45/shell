pragma Singleton

import QtQuick
import Caelestia.Config
import Quickshell
import M3Shapes
import qs.widgets.services

Singleton {
    // The space kept free at the screen's top edge (the edit toolbar stays below it)
    component Bar: QtObject {
        readonly property real zone: 61
    }
    readonly property Bar bar: Bar {}




    component Glass: QtObject {
        // Settings > Style > Glass (the original defaults: 0.72, 0.08)
        readonly property real tint: Math.max(0.2, Math.min(1, GlobalConfig.appearance.glass.tint))
        readonly property real topLight: Math.max(0, Math.min(0.4, GlobalConfig.appearance.glass.topLight))
    }
    readonly property Glass glass: Glass {}

    component Button: QtObject {
        readonly property int size: 40
        readonly property int iconSize: 20
        readonly property int playSize: 56
        readonly property int playIconSize: 28
        readonly property int playSizeSmall: 46
        readonly property int playIconSizeSmall: 24
    }
    readonly property Button button: Button {}


    component BatteryRing: QtObject {
        readonly property int size: 50
        readonly property int thickness: 3
        readonly property real trackOpacity: 0.28
        readonly property real lowLevel: 0.2
    }
    readonly property BatteryRing batteryRing: BatteryRing {}


    component Calendar: QtObject {
        readonly property int width: 320
        readonly property int cellSize: 36
        readonly property int titleSize: 26
        readonly property int dayNumberSize: 40
        readonly property int dayShapeSize: 76
        readonly property int weatherShapeSize: 64
        readonly property int weatherTempSize: 34
        readonly property int weatherIconSize: 30
        readonly property int forecastIconSize: 22
        readonly property int detailIconSize: 16
        readonly property int emptyShapeSize: 48
        readonly property real slideDistance: 0.25
    }
    readonly property Calendar calendar: Calendar {}


    component Tray: QtObject {
        readonly property int menuWidth: 260
        readonly property int iconSize: 22
        readonly property int menuRowHeight: 40
    }
    readonly property Tray tray: Tray {}




    component WidgetEditor: QtObject {
        readonly property int compactWidth: 352
        readonly property int fullWidth: 480
        readonly property int shapeChip: 44
        readonly property int shapeColumns: 7
    }
    readonly property WidgetEditor widgetEditor: WidgetEditor {}

    component DeskMenuTokens: QtObject {
        readonly property int width: 280
        readonly property int tileHeight: 92
        readonly property int tileShape: 44
    }
    readonly property DeskMenuTokens deskMenu: DeskMenuTokens {}

    component EditTokens: QtObject {
        readonly property real dim: 0.35
        readonly property int button: 44
        readonly property int padding: 8
        readonly property int gap: 6
        readonly property int margin: 24
        readonly property int labelGap: 6
        readonly property int labelPadding: 14
        readonly property int outlineGap: 4
        readonly property real outlineWidth: 2
        readonly property real outlineWave: 1.6
        readonly property int outlineWaveLength: 28
        readonly property int outlineLoop: 3200
        readonly property int grab: 14
        readonly property real outlineHot: 1.8
        readonly property int tagHeight: 24
    }
    readonly property EditTokens edit: EditTokens {}

    component SnapTokens: QtObject {
        readonly property int distance: 10
        readonly property int margin: 32
        readonly property int guideWidth: 2
        readonly property int guideOverhang: 16
        readonly property int capLength: 8
        readonly property int labelHeight: 20
        readonly property int labelPadding: 12
        readonly property int labelGap: 6
        readonly property int cell: 20
        readonly property int gridDistance: 6
        readonly property int dotSize: 4
        readonly property int haloSize: 2
        readonly property real haloOpacity: 0.6
        readonly property real gridDim: 0.22
        readonly property int lensSize: 9
        readonly property int lensReach: 260
        readonly property int waveBand: 140
        readonly property int revealDuration: 900
        readonly property real gridOpacity: 0.8
    }
    readonly property SnapTokens snap: SnapTokens {}

    component NowPlaying: QtObject {
        readonly property int margin: 32
        // The default spot's distance from the left edge: past the shell's left bar (Nebula: 32)
        readonly property int marginLeft: 32 + 72
        readonly property int cookieSize: 280
        readonly property int artSize: 88
        readonly property int textWidth: 170
        readonly property int progressWidth: 140
        readonly property int spinUpDuration: 1200
        readonly property int emptySize: 120
        readonly property int emptyIconSize: 48
    }
    readonly property NowPlaying nowPlaying: NowPlaying {}


    component SettingsWindow: QtObject {
        readonly property int width: 940
        readonly property int height: 680
        readonly property int padding: 24
        readonly property int railOpenWidth: 220
        readonly property int railClosedWidth: 64
        readonly property int railButtonSize: 44
        readonly property int railRowHeight: 48
        readonly property int railShapeSize: 34
        readonly property int railLabelHeight: 26
        readonly property int railGroupGap: 12
        readonly property int railRowRadius: 5
        readonly property int rowGap: 3
        readonly property int rowRadius: 4
        readonly property int headerShapeSize: 64
        readonly property int headerIconSize: 30
        readonly property int iconSize: 22
        readonly property int rowHeight: 68
        readonly property int titleSize: 30
        readonly property int heroHeight: 210
        readonly property int swatchSize: 56
        readonly property int thumbWidth: 320
        readonly property int avatarSize: 128
        readonly property int authorSize: 64
        readonly property string github: "LilaccFlowerr"
        readonly property int controlWidth: 260
        readonly property int fieldWidth: 76
        readonly property int logoButton: 36
        readonly property int dialogWidth: 380
        readonly property int expandDuration: 400
        readonly property real fadeScale: 0.96
        readonly property real fadeThroughScale: 0.92
        readonly property int subSlide: 80
    }
    readonly property SettingsWindow settings: SettingsWindow {}




    component FetchTokens: QtObject {
        readonly property int size: 520
        readonly property real stackLogo: 0.62
        readonly property real sideLogo: 0.95
        readonly property int gap: 24
        readonly property real fill: 0.88
        readonly property real backdropDim: 0.6
        readonly property int textSize: 17
        readonly property real swatchScale: 1.4
        readonly property real swatchSpacing: 0.4
        readonly property int swatchGap: 6
    }
    readonly property FetchTokens fetch: FetchTokens {}

    component Radius: QtObject {
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
        readonly property int full: 999
    }
    readonly property Radius radius: Radius {}

    component Spacing: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
    }
    readonly property Spacing spacing: Spacing {}

    component Font: QtObject {
        // The shell's fonts (Nebula: Inter, Material Symbols Rounded, JetBrains Mono)
        readonly property string family: GlobalConfig.appearance.font.body.family
        readonly property string icons: GlobalConfig.appearance.font.icon.family
        readonly property string logos: "Symbols Nerd Font"
        readonly property string mono: GlobalConfig.appearance.font.mono.family
        readonly property int small: 12
        readonly property int normal: 14
        readonly property int large: 16
        readonly property int clock: 20
    }
    readonly property Font font: Font {}

    // The shell's one animation control (Settings > Accessibility: speed, animations off)
    component Anim: QtObject {
        readonly property real scale: GlobalConfig.appearance.anim.durations.scale <= 0.05 ? 0 : GlobalConfig.appearance.anim.durations.scale
        readonly property int fast: Math.round(150 * scale)
        readonly property int medium: Math.round(300 * scale)
        readonly property int slow: Math.round(500 * scale)
        readonly property int island: Math.round(550 * scale)
        readonly property real overshoot: (GlobalConfig.appearance.anim.durations.scale <= 0.05) ? 0 : 1.2

        readonly property list<real> standard:        [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    }
    readonly property Anim anim: Anim {}
}
