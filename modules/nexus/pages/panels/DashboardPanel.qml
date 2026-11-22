pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var toggleMeta: ({
            wifi: Tr.tr("Wi-Fi / Ethernet tile"),
            bluetooth: Tr.tr("Bluetooth tile"),
            desktop: Tr.tr("Desktop mode"),
            mic: Tr.tr("Microphone mute"),
            dnd: Tr.tr("Do not disturb"),
            gameMode: Tr.tr("Game mode"),
            vpn: Tr.tr("VPN"),
            wallpaperPlaying: Tr.tr("Live wallpaper playback"),
            keepAwake: Tr.tr("Keep awake"),
            recorder: Tr.tr("Screen recorder")
        })
    readonly property var visibleToggles: GlobalConfig.utilities.quickToggles.values.filter(e => toggleMeta[e.id] !== undefined)

    function ensureKnownToggles(): void {
        const have = new Set(GlobalConfig.utilities.quickToggles.values.map(e => e.id));
        for (const id of Object.keys(toggleMeta)) {
            if (!have.has(id))
                GlobalConfig.utilities.quickToggles.insert({
                    id,
                    enabled: true
                });
        }
    }

    function moveToggle(id: string, delta: int): void {
        const subset = visibleToggles;
        const pos = subset.findIndex(e => e.id === id);
        const targetPos = pos + delta;
        if (pos < 0 || targetPos < 0 || targetPos >= subset.length)
            return;
        const all = GlobalConfig.utilities.quickToggles.values;
        const fromIdx = all.indexOf(subset[pos]);
        const toIdx = all.indexOf(subset[targetPos]);
        if (fromIdx >= 0 && toIdx >= 0 && fromIdx !== toIdx)
            GlobalConfig.utilities.quickToggles.move(fromIdx, toIdx);
    }

    Component.onCompleted: ensureKnownToggles()

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

        // Quick settings toggles shown in the pill/quick island
        SectionHeader {
            text: Tr.tr("Quick settings")
        }

        Repeater {
            model: root.visibleToggles

            ConnectedRect {
                id: qtRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: qtRowLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: qtRowLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: root.toggleMeta[qtRow.modelData.id] ?? qtRow.modelData.id
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    IconButton {
                        visible: qtRow.modelData.id !== "wifi" && qtRow.modelData.id !== "bluetooth"
                        icon: "arrow_upward"
                        type: IconButton.Text
                        disabled: {
                            const prev = root.visibleToggles[qtRow.index - 1];
                            return !prev || prev.id === "wifi" || prev.id === "bluetooth";
                        }
                        onClicked: root.moveToggle(qtRow.modelData.id, -1)
                    }

                    IconButton {
                        visible: qtRow.modelData.id !== "wifi" && qtRow.modelData.id !== "bluetooth"
                        icon: "arrow_downward"
                        type: IconButton.Text
                        disabled: qtRow.index >= root.visibleToggles.length - 1
                        onClicked: root.moveToggle(qtRow.modelData.id, 1)
                    }

                    StyledSwitch {
                        cLayer: 2
                        checked: qtRow.modelData.enabled
                        onToggled: qtRow.modelData.enabled = checked
                    }
                }
            }
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
