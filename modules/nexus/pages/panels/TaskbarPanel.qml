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

    readonly property bool isPill: ShellStyle.current === "compact"
    readonly property var pillEntries: GlobalConfig.bar.entries.values.filter(e => e.id === "logo" || e.id === "taskbar" || e.id === "tray")

    function entryTitle(id: string): string {
        if (id === "logo")
            return Tr.tr("Launcher button");
        if (id === "taskbar")
            return Tr.tr("Open apps");
        if (id === "tray")
            return Tr.tr("System tray");
        return id;
    }

    function entrySubtext(id: string): string {
        if (id === "logo")
            return Tr.tr("OS icon at the start of the pill to open the launcher");
        if (id === "taskbar")
            return Tr.tr("Running and pinned app icons");
        if (id === "tray")
            return Tr.tr("Background app status icons when any are running");
        return "";
    }

    function movePillEntry(id: string, delta: int): void {
        const subset = pillEntries;
        const pos = subset.findIndex(e => e.id === id);
        const targetPos = pos + delta;
        if (pos < 0 || targetPos < 0 || targetPos >= subset.length)
            return;
        const all = GlobalConfig.bar.entries.values;
        const fromIdx = all.indexOf(subset[pos]);
        const toIdx = all.indexOf(subset[targetPos]);
        if (fromIdx >= 0 && toIdx >= 0 && fromIdx !== toIdx)
            GlobalConfig.bar.entries.move(fromIdx, toIdx);
    }

    title: Tr.tr("Taskbar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        SelectRow {
            label: Tr.tr("Visibility")
            subtext: root.isPill ? Tr.tr("How the pill opens") : Tr.tr("How the bar opens")
            menuItems: [alwaysItem, hoverItem, dragItem]
            active: Config.bar.persistent ? alwaysItem : Config.bar.showOnHover ? hoverItem : dragItem
            onSelected: item => {
                if (item.value === "persistent") {
                    GlobalConfig.bar.persistent = true;
                } else {
                    GlobalConfig.bar.persistent = false;
                    GlobalConfig.bar.showOnHover = item.value === "hover";
                }
            }

            MenuItem {
                id: alwaysItem

                text: Tr.tr("Always shown")
                value: "persistent"
            }

            MenuItem {
                id: hoverItem

                text: Tr.tr("Show on hover")
                value: "hover"
            }

            MenuItem {
                id: dragItem

                text: Tr.tr("Pull from edge")
                value: "drag"
            }
        }

        ToggleRow {
            text: Tr.tr("Window previews")
            subtext: root.isPill ? Tr.tr("Hovering an app on the pill shows its windows") : Tr.tr("Hovering an app on the bar shows its windows")
            checked: Config.bar.popouts.taskbar
            onToggled: GlobalConfig.bar.popouts.taskbar = checked
        }

        ToggleRow {
            text: Tr.tr("Over fullscreen apps")
            subtext: root.isPill ? Tr.tr("The islands and the pill can open over a fullscreen window") : Tr.tr("Panels and the bar can open over a fullscreen window")
            checked: Config.general.showOverFullscreen
            onToggled: GlobalConfig.general.showOverFullscreen = checked
        }

        StepperRow {
            visible: !Config.bar.persistent
            label: Tr.tr("Drag threshold")
            subtext: root.isPill ? Tr.tr("Distance dragged from the edge before the pill comes out") : Tr.tr("Distance dragged from the edge before the bar comes out")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Items & order
        SectionHeader {
            text: Tr.tr("Items & order")
        }

        Repeater {
            model: root.pillEntries

            ConnectedRect {
                id: entryRow

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: entryRowLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: entryRowLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.small

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.entryTitle(entryRow.modelData.id)
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.entrySubtext(entryRow.modelData.id)
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            wrapMode: Text.WordWrap
                        }
                    }

                    IconButton {
                        icon: "arrow_upward"
                        type: IconButton.Text
                        disabled: entryRow.index === 0
                        onClicked: root.movePillEntry(entryRow.modelData.id, -1)
                    }

                    IconButton {
                        icon: "arrow_downward"
                        type: IconButton.Text
                        disabled: entryRow.index >= root.pillEntries.length - 1
                        onClicked: root.movePillEntry(entryRow.modelData.id, 1)
                    }

                    StyledSwitch {
                        cLayer: 2
                        checked: entryRow.modelData.enabled
                        onToggled: entryRow.modelData.enabled = checked
                    }
                }
            }
        }

        // Components
        SectionHeader {
            text: Tr.tr("Components")
        }

        NavRow {
            icon: "widgets"
            text: Tr.tr("Tray")
            subtext: Tr.tr("System tray icons")
            onClicked: root.nState.openSubPage(4)
        }

        // Scroll actions
        SectionHeader {
            text: Tr.tr("Scroll actions")
        }

        ToggleRow {
            text: Tr.tr("Volume")
            subtext: Tr.tr("Scroll on the top half of the screen edge to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            text: Tr.tr("Brightness")
            subtext: Tr.tr("Scroll on the bottom half of the screen edge to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}
