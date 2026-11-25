pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Desktop")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Desktop")
        }

        ToggleRow {
            text: Tr.tr("Desktop icons")
            subtext: Tr.tr("Show what's in the Desktop folder on the desktop")
            checked: Config.background.desktopIcons
            onToggled: GlobalConfig.background.desktopIcons = checked
        }

        SliderRow {
            visible: Config.background.desktopIcons
            icon: "opacity"
            label: Tr.tr("Desktop icon opacity")
            value: GlobalConfig.background.desktopIconOpacity
            valueLabel: `${Math.round(value * 100)}%`
            onMoved: v => GlobalConfig.background.desktopIconOpacity = v
        }

        // Desktop widgets (see widgets/README.md): clock, calendar, weather... in glass shapes
        SectionHeader {
            text: Tr.tr("Desktop widgets")
        }

        ToggleRow {
            text: Tr.tr("Desktop widgets")
            subtext: Tr.tr("Clock, calendar, weather, battery, now playing, lyrics, pictures, notes and system info in Material shapes on the desktop")
            checked: GlobalConfig.appearance.style.desktopWidgets
            onToggled: GlobalConfig.appearance.style.desktopWidgets = checked
        }

        NavRow {
            Layout.fillWidth: true
            visible: GlobalConfig.appearance.style.desktopWidgets
            icon: "widgets"
            text: Tr.tr("Widgets and layouts")
            subtext: Tr.tr("Add, change and arrange them. On the desktop: right-click for the menu; Super+Shift+E to edit")
            onClicked: root.nState.openSubPage(9)
        }

        SliderRow {
            visible: GlobalConfig.appearance.style.desktopWidgets
            icon: "blur_on"
            label: Tr.tr("Glass tint")
            valueLabel: `${Math.round(GlobalConfig.appearance.glass.tint * 100)}%`
            // 30% (clear) .. 100% (solid)
            value: (GlobalConfig.appearance.glass.tint - 0.3) / 0.7
            onMoved: v => GlobalConfig.appearance.glass.tint = Math.round((0.3 + v * 0.7) * 100) / 100
        }

        SliderRow {
            visible: GlobalConfig.appearance.style.desktopWidgets
            icon: "wb_twilight"
            label: Tr.tr("Light across the top")
            valueLabel: `${Math.round(GlobalConfig.appearance.glass.topLight * 100)}%`
            // 0 .. 30%
            value: GlobalConfig.appearance.glass.topLight / 0.3
            onMoved: v => GlobalConfig.appearance.glass.topLight = Math.round(v * 30) / 100
        }

        // Bars that move with the music, on the wallpaper
        SectionHeader {
            text: Tr.tr("Audio visualiser")
        }

        ToggleRow {
            text: Tr.tr("Visualiser on the desktop")
            subtext: Tr.tr("Bars at the bottom of the wallpaper that move with what's playing")
            checked: Config.background.visualiser.enabled
            onToggled: GlobalConfig.background.visualiser.enabled = checked
        }

        ToggleRow {
            visible: Config.background.visualiser.enabled
            text: Tr.tr("Hide when windows cover the desktop")
            checked: Config.background.visualiser.autoHide
            onToggled: GlobalConfig.background.visualiser.autoHide = checked
        }

        StepperRow {
            visible: Config.background.visualiser.enabled
            // TRANSLATORS: bars of a spectrum analyser, not the taskbar
            label: Tr.tr("Visualiser bars")
            subtext: Tr.tr("Number of bars in the audio visualisers")
            value: GlobalConfig.services.visualiserBars
            from: 10
            to: 120
            stepSize: 2
            onMoved: v => GlobalConfig.services.visualiserBars = v
        }
    }
}
