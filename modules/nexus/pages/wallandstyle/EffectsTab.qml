pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    property bool showAdvancedBlur: false
    readonly property bool blurOn: HyprSettings.value("decoration:blur:enabled", true)
    // The Deep glass look's panel opacity (its other values are in the Look menu)
    readonly property real frostedBase: 0.55
    readonly property bool frostedPanels: GlobalConfig.appearance.transparency.enabled && Math.abs(GlobalConfig.appearance.transparency.base - frostedBase) < 0.005
    readonly property int winBlurSize: HyprSettings.value("decoration:blur:size", 8)
    readonly property int winBlurPasses: HyprSettings.value("decoration:blur:passes", 2)

    title: Tr.tr("Effects")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Transparency & shape")
        }

        ToggleRow {
            text: Tr.tr("Transparency")
            // TRANSLATORS: %1/%2 = opacity percentage values for the base surface and layered surfaces
            subtext: Tr.tr("Panels %1%, inner cards %2%").arg(Math.round(Colours.transparency.base * 100)).arg(Math.round(Colours.transparency.layers * 100))
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        SliderRow {
            visible: Colours.transparency.enabled
            icon: "opacity"
            label: Tr.tr("Panel opacity")
            subtext: Tr.tr("Panels, the bar, the launcher and menus")
            valueLabel: `${Math.round(GlobalConfig.appearance.transparency.base * 100)}%`
            value: GlobalConfig.appearance.transparency.base
            onMoved: v => GlobalConfig.appearance.transparency.base = Math.round(v * 100) / 100
        }

        SliderRow {
            visible: Colours.transparency.enabled
            icon: "layers"
            label: Tr.tr("Inner card opacity")
            subtext: Tr.tr("Cards, buttons and controls inside panels")
            valueLabel: `${Math.round(GlobalConfig.appearance.transparency.layers * 100)}%`
            value: GlobalConfig.appearance.transparency.layers
            onMoved: v => GlobalConfig.appearance.transparency.layers = Math.round(v * 100) / 100
        }

        SliderRow {
            icon: "rounded_corner"
            label: Tr.tr("Roundness of the shell")
            subtext: Tr.tr("Buttons, cards, menus and panels")
            valueLabel: `${Math.round(Config.appearance.rounding.scale * 100)}%`
            // 0% (square) .. 200%
            value: Config.appearance.rounding.scale / 2
            onMoved: v => GlobalConfig.appearance.rounding.scale = Math.round(v * 40) / 20
        }

        NavRow {
            icon: "rounded_corner"
            text: Tr.tr("Window and screen corners")
            subtext: Tr.tr("Corner rounding for windows and the screen frame, on Windows › Look")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("windows"),
                tab: "windows-look",
                path: [],
                text: Tr.tr("Window corners")
            })
        }

        // Every blur setting for windows, shell panels and desktop items
        SectionHeader {
            text: Tr.tr("Blur")
        }

        ToggleRow {
            text: Tr.tr("Blur")
            subtext: Tr.tr("Frosted glass behind see-through windows, panels, the bar and widgets")
            checked: HyprSettings.value("decoration:blur:enabled", true)
            onToggled: HyprSettings.setOption("decoration:blur:enabled", checked)
        }

        SelectRow {
            visible: root.blurOn
            label: Tr.tr("Look")
            subtext: Tr.tr("Sets windows' blur strength and panel glass preset")
            menuItems: [nebulaBlur, strongBlur, frostedBlur]
            active: root.winBlurSize === 4 && root.winBlurPasses === 1 ? nebulaBlur : root.winBlurSize === 8 && root.winBlurPasses === 2 ? strongBlur : root.winBlurSize === 8 && root.winBlurPasses === 3 && (root.frostedPanels || (GlobalConfig.appearance.blur.shellSize === 12 && GlobalConfig.appearance.blur.shellPasses === 4)) ? frostedBlur : null
            fallbackText: Tr.tr("Custom")
            onSelected: item => {
                HyprSettings.setOption("decoration:blur:size", item.value[0]);
                HyprSettings.setOption("decoration:blur:passes", item.value[1]);
                const t = GlobalConfig.appearance.transparency;
                const b = GlobalConfig.appearance.blur;
                if (item === frostedBlur) {
                    // Deep glass: see-through panels over a heavy blur
                    t.enabled = true;
                    t.base = root.frostedBase;
                    t.layers = 0.3;
                    b.shellSize = 12;
                    b.shellPasses = 4;
                } else if (root.frostedPanels) {
                    // Leaving Deep glass: undo what it set. The panel blur goes back
                    // only here, so a 12/4 the person chose themselves stays
                    t.base = 0.85;
                    t.layers = 0.4;
                    if (b.shellSize === 12 && b.shellPasses === 4) {
                        b.shellSize = 0;
                        b.shellPasses = 0;
                    }
                }
            }

            MenuItem {
                id: nebulaBlur

                text: Tr.tr("Soft: shapes show through")
                value: [4, 1]
            }

            MenuItem {
                id: strongBlur

                text: Tr.tr("Strong: frosted")
                value: [8, 2]
            }

            MenuItem {
                id: frostedBlur

                text: Tr.tr("Deep glass: see-through panels, heavy blur")
                value: [8, 3]
            }
        }

        RowButton {
            visible: root.blurOn
            icon: root.showAdvancedBlur ? "expand_less" : "expand_more"
            text: Tr.tr("Fine-tune blur by surface")
            subtext: Tr.tr("Separate blur strength and smoothness for windows, panels and widgets")
            onClicked: root.showAdvancedBlur = !root.showAdvancedBlur
        }

        BlurRow {
            visible: root.blurOn && root.showAdvancedBlur
            label: Tr.tr("Windows")
            subtext: Tr.tr("See-through windows; also everything below set to \"as windows\"")
            size: root.winBlurSize
            passes: root.winBlurPasses
            minimum: 1
            onSizeMoved: v => HyprSettings.setOption("decoration:blur:size", v)
            onPassesMoved: v => HyprSettings.setOption("decoration:blur:passes", v)
        }

        BlurRow {
            visible: root.blurOn && root.showAdvancedBlur
            label: ShellStyle.current === "full" ? Tr.tr("Panels and bar") : Tr.tr("Islands and pill")
            subtext: ShellStyle.current === "full" ? Tr.tr("The bar, side panels, launcher, notifications and menus") : Tr.tr("The pill, the top island, the launcher, notifications and menus")
            size: GlobalConfig.appearance.blur.shellSize
            passes: GlobalConfig.appearance.blur.shellPasses
            onSizeMoved: v => GlobalConfig.appearance.blur.shellSize = v
            onPassesMoved: v => GlobalConfig.appearance.blur.shellPasses = v
        }

        BlurRow {
            visible: root.blurOn && root.showAdvancedBlur
            label: Tr.tr("Desktop widgets")
            subtext: Tr.tr("The desktop widgets and their menus")
            size: GlobalConfig.appearance.blur.widgetsSize
            passes: GlobalConfig.appearance.blur.widgetsPasses
            onSizeMoved: v => GlobalConfig.appearance.blur.widgetsSize = v
            onPassesMoved: v => GlobalConfig.appearance.blur.widgetsPasses = v
        }

        ToggleRow {
            visible: root.blurOn && Config.background.visualiser.enabled
            text: Tr.tr("Audio visualiser")
            subtext: Tr.tr("The visualiser's bars on the desktop")
            checked: Config.background.visualiser.blur
            onToggled: GlobalConfig.background.visualiser.blur = checked
        }
    }

    // Strength (blur size) and smoothness (passes) of one kind of surface; 0 = "as windows"
    component BlurRow: ColumnLayout {
        id: blurRow

        property string label
        property string subtext
        property int size
        property int passes
        property int minimum: 0

        signal sizeMoved(int v)
        signal passesMoved(int v)

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall / 2

        StepperRow {
            label: blurRow.label
            subtext: blurRow.minimum === 0 && blurRow.size === 0 ? blurRow.subtext + " · " + Tr.tr("strength as windows") : blurRow.subtext + " · " + Tr.tr("strength")
            value: blurRow.size
            from: blurRow.minimum
            to: 20
            stepSize: 1
            onMoved: v => blurRow.sizeMoved(v)
        }

        StepperRow {
            label: Tr.tr("%1: smoothness").arg(blurRow.label)
            subtext: blurRow.minimum === 0 && blurRow.passes === 0 ? Tr.tr("More passes make the blur smoother and use more GPU · as windows") : Tr.tr("More passes make the blur smoother and use more GPU")
            value: blurRow.passes
            from: blurRow.minimum
            to: 6
            stepSize: 1
            onMoved: v => blurRow.passesMoved(v)
        }
    }
}
