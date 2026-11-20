pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Dashboard")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            text: Tr.tr("General")
        }

        ToggleRow {
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }

        // Tabs
        SectionHeader {
            text: Tr.tr("Pages")
        }

        ToggleRow {
            text: Tr.tr("Overview")
            checked: Config.dashboard.showDashboard
            onToggled: GlobalConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: Tr.tr("Media")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: Tr.tr("Performance")
            checked: Config.dashboard.showPerformance
            onToggled: GlobalConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            text: Tr.tr("Weather")
            checked: Config.dashboard.showWeather
            onToggled: GlobalConfig.dashboard.showWeather = checked
        }

        ToggleRow {
            text: Tr.tr("Wallpapers")
            subtext: Tr.tr("Pick a picture or a live wallpaper from the dashboard")
            checked: Config.dashboard.showWallpapers
            onToggled: GlobalConfig.dashboard.showWallpapers = checked
        }

        // Performance gauges
        SectionHeader {
            visible: Config.dashboard.showPerformance
            text: Tr.tr("Performance gauges")
        }

        ToggleRow {
            visible: Config.dashboard.showPerformance
            text: Tr.tr("Processor")
            checked: Config.dashboard.performance.showCpu
            onToggled: GlobalConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            visible: Config.dashboard.showPerformance
            text: Tr.tr("Graphics")
            checked: Config.dashboard.performance.showGpu
            onToggled: GlobalConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            visible: Config.dashboard.showPerformance
            text: Tr.tr("Memory")
            checked: Config.dashboard.performance.showMemory
            onToggled: GlobalConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            visible: Config.dashboard.showPerformance
            text: Tr.tr("Storage")
            checked: Config.dashboard.performance.showStorage
            onToggled: GlobalConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            visible: Config.dashboard.showPerformance
            text: Tr.tr("Network speed")
            checked: Config.dashboard.performance.showNetwork
            onToggled: GlobalConfig.dashboard.performance.showNetwork = checked
        }

        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        StepperRow {
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Distance dragged down from the top edge before the dashboard opens")
            value: Config.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.dragThreshold = v
        }
    }
}
