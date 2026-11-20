pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property bool isPill: ShellStyle.current === "compact"

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
