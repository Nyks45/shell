pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Workspaces")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StepperRow {
            first: true
            // TRANSLATORS: the number of workspaces shown on the bar
            label: Tr.trCtx("Shown", "bar workspaces")
            subtext: Tr.tr("Number of workspaces displayed")
            value: Config.bar.workspaces.shown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.shown = v
        }

        ToggleRow {
            text: Tr.trCtx("Active indicator", "bar workspaces")
            checked: Config.bar.workspaces.activeIndicator
            onToggled: GlobalConfig.bar.workspaces.activeIndicator = checked
        }

        ToggleRow {
            text: Tr.trCtx("Active trail", "bar workspaces")
            checked: Config.bar.workspaces.activeTrail
            onToggled: GlobalConfig.bar.workspaces.activeTrail = checked
        }

        ToggleRow {
            text: Tr.trCtx("Occupied background", "bar workspaces")
            checked: Config.bar.workspaces.occupiedBg
            onToggled: GlobalConfig.bar.workspaces.occupiedBg = checked
        }

        ToggleRow {
            text: Tr.trCtx("Show unoccupied", "bar workspaces")
            subtext: Tr.tr("Show workspaces that are inactive and empty")
            checked: Config.bar.workspaces.showUnoccupied
            onToggled: GlobalConfig.bar.workspaces.showUnoccupied = checked
        }

        ToggleRow {
            text: Tr.trCtx("Show windows", "bar workspaces")
            subtext: Tr.tr("Show icons of open windows on each workspace")
            checked: Config.bar.workspaces.showWindows
            onToggled: GlobalConfig.bar.workspaces.showWindows = checked
        }

        ToggleRow {
            text: Tr.trCtx("Windows on special workspaces", "bar workspaces")
            checked: Config.bar.workspaces.showWindowsOnSpecialWorkspaces
            onToggled: GlobalConfig.bar.workspaces.showWindowsOnSpecialWorkspaces = checked
        }

        SelectRow {
            label: Tr.tr("Workspace style")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Shapes")
                    value: BarWorkspaceDisplay.Shapes
                },
                MenuItem {
                    text: Tr.tr("Numbers or names")
                    value: BarWorkspaceDisplay.Text
                },
                MenuItem {
                    text: Tr.tr("Icons")
                    value: BarWorkspaceDisplay.Icons
                }
            ]
            active: menuItems.find(i => i.value === Config.bar.workspaces.displayType) ?? null
            onSelected: item => GlobalConfig.bar.workspaces.displayType = item.value
        }

        SelectRow {
            visible: Config.bar.workspaces.displayType === BarWorkspaceDisplay.Text
            label: Tr.tr("Names in")
            menuItems: [
                MenuItem {
                    text: Tr.tr("As they are")
                    value: BarWorkspaceCapitalisation.Preserve
                },
                MenuItem {
                    text: Tr.tr("CAPITALS")
                    value: BarWorkspaceCapitalisation.Upper
                },
                MenuItem {
                    text: Tr.tr("lower case")
                    value: BarWorkspaceCapitalisation.Lower
                }
            ]
            active: menuItems.find(i => i.value === Config.bar.workspaces.capitalisation) ?? null
            onSelected: item => GlobalConfig.bar.workspaces.capitalisation = item.value
        }

        StepperRow {
            last: true
            // TRANSLATORS: maximum number of window icons shown per workspace
            label: Tr.trCtx("Max window icons", "bar workspaces")
            value: Config.bar.workspaces.maxWindowIcons
            from: 0
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.maxWindowIcons = v
        }
    }
}
