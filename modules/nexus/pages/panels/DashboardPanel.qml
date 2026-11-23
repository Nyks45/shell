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
    // The pill's own toggles (utilities.pillQuickToggles; the full style's
    // quickToggles stay as they are): known ids once each, missing ones shown
    // on (written on the first edit). Wi-Fi and Bluetooth are the two wide
    // tiles on top: only the round toggles are reordered, among themselves.
    readonly property list<string> tileIds: ["wifi", "bluetooth"]
    readonly property var visibleToggles: {
        const seen = {};
        const out = [];
        for (const e of GlobalConfig.utilities.pillQuickToggles.values) {
            if (toggleMeta[e.id] === undefined || seen[e.id])
                continue;
            seen[e.id] = true;
            out.push({
                id: e.id,
                enabled: e.enabled
            });
        }
        for (const id of Object.keys(toggleMeta))
            if (!seen[id])
                out.push({
                    id,
                    enabled: true
                });
        return [...out.filter(e => tileIds.includes(e.id)), ...out.filter(e => !tileIds.includes(e.id))];
    }

    function saveToggles(list: var): void {
        const node = GlobalConfig.utilities.pillQuickToggles;
        node.clear();
        for (const e of list)
            node.insert({
                id: e.id,
                enabled: e.enabled
            });
    }

    function setToggleEnabled(id: string, on: bool): void {
        saveToggles(visibleToggles.map(e => e.id === id ? {
                id,
                enabled: on
            } : e));
    }

    function moveToggle(id: string, delta: int): void {
        const list = visibleToggles.slice();
        const pos = list.findIndex(e => e.id === id);
        const target = pos + delta;
        if (pos < 0 || tileIds.includes(id) || target < 0 || target >= list.length || tileIds.includes(list[target].id))
            return;
        const [item] = list.splice(pos, 1);
        list.splice(target, 0, item);
        saveToggles(list);
    }

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
                        onToggled: root.setToggleEnabled(qtRow.modelData.id, checked)
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
