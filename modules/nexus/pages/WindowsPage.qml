pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.modules.nexus.common

// How windows look (Hyprland: gaps, borders, corners, blur, shadows,
// animations) and the screen's own frame (the shell's border).
PageBase {
    id: root

    // "5 5 5 5" (css gaps) -> 5
    function firstNumber(v: var, fallback: real): real {
        const n = parseFloat(String(v ?? "").split(/\s+/)[0]);
        return isNaN(n) ? fallback : n;
    }

    title: Tr.tr("Windows")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Spacing")
        }

        StepperRow {
            first: true
            label: Tr.tr("Gap between windows")
            subtext: Tr.tr("In pixels")
            value: root.firstNumber(HyprSettings.value("general:gaps_in", 5), 5)
            from: 0
            to: 40
            stepSize: 1
            onMoved: v => HyprSettings.setOption("general:gaps_in", v)
        }

        StepperRow {
            last: true
            label: Tr.tr("Gap to the screen edges")
            subtext: Tr.tr("In pixels")
            value: root.firstNumber(HyprSettings.value("general:gaps_out", 10), 10)
            from: 0
            to: 80
            stepSize: 1
            onMoved: v => HyprSettings.setOption("general:gaps_out", v)
        }

        SectionHeader {
            text: Tr.tr("Frame")
        }

        StepperRow {
            first: true
            label: Tr.tr("Border thickness")
            subtext: Tr.tr("The coloured line around windows; 0 for none")
            value: HyprSettings.value("general:border_size", 1)
            from: 0
            to: 10
            stepSize: 1
            onMoved: v => HyprSettings.setOption("general:border_size", v)
        }

        StepperRow {
            label: Tr.tr("Corner rounding")
            subtext: Tr.tr("Radius of window corners; 0 for square")
            value: HyprSettings.value("decoration:rounding", 0)
            from: 0
            to: 40
            stepSize: 1
            onMoved: v => HyprSettings.setOption("decoration:rounding", v)
        }

        SliderRow {
            last: true
            icon: "opacity"
            label: Tr.tr("Window opacity")
            valueLabel: `${Math.round(HyprSettings.varValue("windowOpacity", 0.95) * 100)}%`
            // 50% .. 100%
            value: (HyprSettings.varValue("windowOpacity", 0.95) - 0.5) / 0.5
            onMoved: v => HyprSettings.setVar("windowOpacity", Math.round((0.5 + v * 0.5) * 100) / 100)
        }

        SectionHeader {
            text: Tr.tr("Effects")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Blur")
            subtext: Tr.tr("Frosted glass behind see-through windows and panels")
            checked: HyprSettings.value("decoration:blur:enabled", true)
            onToggled: HyprSettings.setOption("decoration:blur:enabled", checked)
        }

        StepperRow {
            visible: HyprSettings.value("decoration:blur:enabled", true)
            label: Tr.tr("Blur strength")
            value: HyprSettings.value("decoration:blur:size", 8)
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => HyprSettings.setOption("decoration:blur:size", v)
        }

        StepperRow {
            visible: HyprSettings.value("decoration:blur:enabled", true)
            label: Tr.tr("Blur passes")
            subtext: Tr.tr("More is smoother, and costs more")
            value: HyprSettings.value("decoration:blur:passes", 2)
            from: 1
            to: 6
            stepSize: 1
            onMoved: v => HyprSettings.setOption("decoration:blur:passes", v)
        }

        ToggleRow {
            text: Tr.tr("Shadows")
            checked: HyprSettings.value("decoration:shadow:enabled", true)
            onToggled: HyprSettings.setOption("decoration:shadow:enabled", checked)
        }

        StepperRow {
            visible: HyprSettings.value("decoration:shadow:enabled", true)
            label: Tr.tr("Shadow size")
            value: HyprSettings.value("decoration:shadow:range", 15)
            from: 2
            to: 60
            stepSize: 2
            onMoved: v => HyprSettings.setOption("decoration:shadow:range", v)
        }

        ToggleRow {
            text: Tr.tr("Dim inactive windows")
            subtext: Tr.tr("Windows you're not using are slightly darker")
            checked: HyprSettings.value("decoration:dim_inactive", false)
            onToggled: HyprSettings.setOption("decoration:dim_inactive", checked)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Animations")
            subtext: Tr.tr("Windows and workspaces move instead of appearing at once")
            checked: HyprSettings.value("animations:enabled", true)
            onToggled: HyprSettings.setOption("animations:enabled", checked)
        }

        SectionHeader {
            text: Tr.tr("Screen")
        }

        StepperRow {
            first: true
            label: Tr.tr("Screen frame")
            subtext: Tr.tr("Thickness of the shell's frame around the screen; 0 for none")
            value: Config.border.thickness
            from: 0
            to: 30
            stepSize: 1
            onMoved: v => GlobalConfig.border.thickness = v
        }

        StepperRow {
            last: true
            label: Tr.tr("Screen corners")
            subtext: Tr.tr("Rounding of the screen's corners (maximized windows follow it)")
            value: Config.border.rounding
            from: 0
            to: 60
            stepSize: 1
            onMoved: v => {
                GlobalConfig.border.rounding = v;
                HyprSettings.reloadSoon();
            }
        }
    }
}
