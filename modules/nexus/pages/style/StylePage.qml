pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Style: the parts of the Nebula look (github.com/LilaccFlowerr/Nebula, see NEBULA.md), each
// one an option next to the shell's own.
PageBase {
    id: root

    title: Tr.tr("Style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Desktop widgets")
        }

        ToggleRow {
            text: Tr.tr("Desktop widgets")
            subtext: Tr.tr("Clock, calendar, weather, battery, now playing, lyrics, pictures, notes and system info in Material shapes on the desktop")
            checked: GlobalConfig.appearance.style.desktopWidgets
            onToggled: GlobalConfig.appearance.style.desktopWidgets = checked
        }

        RowButton {
            Layout.fillWidth: true
            visible: GlobalConfig.appearance.style.desktopWidgets
            icon: "widgets"
            text: Tr.tr("Widgets and layouts")
            subtext: Tr.tr("Add, change and arrange them. On the desktop: right-click for the menu; Super+Shift+E to edit")
            onClicked: root.nState.openSubPage(1)
        }

        SectionHeader {
            text: Tr.tr("Glass")
        }

        // Hyprland has one blur for everything (windows too): Nebula's is lighter (size 4, one
        // pass), so the glass still shows the shapes behind it. Saved as the Windows page's blur.
        SelectRow {
            readonly property bool nebula: HyprSettings.value("decoration:blur:size", 8) === 4 && HyprSettings.value("decoration:blur:passes", 2) === 1

            label: Tr.tr("Blur")
            subtext: Tr.tr("Behind glass, panels and see-through windows")
            menuItems: [nebulaBlur, strongBlur]
            active: nebula ? nebulaBlur : HyprSettings.value("decoration:blur:size", 8) === 8 && HyprSettings.value("decoration:blur:passes", 2) === 2 ? strongBlur : null
            fallbackText: Tr.tr("Your own (Windows page)")
            onSelected: item => {
                HyprSettings.setOption("decoration:blur:enabled", true);
                HyprSettings.setOption("decoration:blur:size", item.value[0]);
                HyprSettings.setOption("decoration:blur:passes", item.value[1]);
            }

            MenuItem {
                id: nebulaBlur

                text: Tr.tr("Nebula: soft, shapes show through")
                value: [4, 1]
            }

            MenuItem {
                id: strongBlur

                text: Tr.tr("Strong: frosted")
                value: [8, 2]
            }
        }

        SliderRow {
            icon: "blur_on"
            label: Tr.tr("Glass tint")
            // TRANSLATORS: how opaque glass cards and widgets are
            valueLabel: `${Math.round(GlobalConfig.appearance.glass.tint * 100)}%`
            // 30% (clear) .. 100% (solid)
            value: (GlobalConfig.appearance.glass.tint - 0.3) / 0.7
            onMoved: v => GlobalConfig.appearance.glass.tint = Math.round((0.3 + v * 0.7) * 100) / 100
        }

        SliderRow {
            icon: "wb_twilight"
            label: Tr.tr("Light across the top")
            valueLabel: `${Math.round(GlobalConfig.appearance.glass.topLight * 100)}%`
            // 0 .. 30%
            value: GlobalConfig.appearance.glass.topLight / 0.3
            onMoved: v => GlobalConfig.appearance.glass.topLight = Math.round(v * 30) / 100
        }
    }
}
