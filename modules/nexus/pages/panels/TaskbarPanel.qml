pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

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

        ToggleRow {
            text: Tr.tr("Persistent")
            subtext: Tr.tr("Keep the pill out at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Bring the pill out when the cursor reaches the middle of the left edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        ToggleRow {
            text: Tr.tr("Window previews")
            subtext: Tr.tr("Hovering an app on the pill shows its windows")
            checked: Config.bar.popouts.taskbar
            onToggled: GlobalConfig.bar.popouts.taskbar = checked
        }

        ToggleRow {
            text: Tr.tr("Over fullscreen apps")
            subtext: Tr.tr("The islands and the pill can open over a fullscreen window")
            checked: Config.general.showOverFullscreen
            onToggled: GlobalConfig.general.showOverFullscreen = checked
        }

        StepperRow {
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the pill comes out")
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
