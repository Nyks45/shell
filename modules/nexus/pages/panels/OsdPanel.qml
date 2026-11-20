pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("On-screen display")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("General")
        }

        ToggleRow {
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("A small island at the right edge when the volume or brightness changes")
            checked: Config.osd.enabled
            onToggled: GlobalConfig.osd.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Brightness")
            checked: Config.osd.enableBrightness
            onToggled: GlobalConfig.osd.enableBrightness = checked
        }

        ToggleRow {
            text: Tr.tr("Microphone")
            checked: Config.osd.enableMicrophone
            onToggled: GlobalConfig.osd.enableMicrophone = checked
        }

        SelectRow {
            label: Tr.tr("Hide after")
            subtext: Tr.tr("How long the on-screen display stays visible")
            menuOnTop: true
            menuItems: osdDelayItems.instances
            active: osdDelayItems.instances.find(i => i.value === Config.osd.hideDelay) ?? null
            fallbackText: Tr.tr("%1 s").arg((Config.osd.hideDelay / 1000).toFixed(1).replace(/\.0$/, ""))
            onSelected: item => GlobalConfig.osd.hideDelay = item.value

            Variants {
                id: osdDelayItems

                model: [1000, 1500, 2000, 3000, 5000]

                MenuItem {
                    required property int modelData

                    text: modelData === 1000 ? Tr.tr("1 second") : Tr.tr("%1 seconds").arg(modelData / 1000)
                    value: modelData
                }
            }
        }
    }
}
