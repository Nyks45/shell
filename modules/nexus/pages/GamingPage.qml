pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// Gaming: Caelestia's game mode, screen tearing (lower latency), keeping the
// screen awake in fullscreen, and links to VRR and notifications in fullscreen.
PageBase {
    id: root

    title: Tr.tr("Gaming")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Game mode")
        }

        ToggleRow {
            text: Tr.tr("Game mode")
            subtext: Tr.tr("Turns off animations, blur, shadows, gaps and rounding, and allows tearing, until it's turned off")
            checked: RuntimeState.gameMode
            onToggled: RuntimeState.gameMode = checked
        }

        SectionHeader {
            text: Tr.tr("Performance")
        }

        ToggleRow {
            text: Tr.tr("Allow screen tearing")
            subtext: Tr.tr("Lower input lag for games that ask for it; per app under Workspaces & focus > App rules")
            checked: HyprSettings.value("general:allow_tearing", false)
            onToggled: HyprSettings.setOption("general:allow_tearing", checked)
        }

        ToggleRow {
            text: Tr.tr("Keep the screen awake in fullscreen")
            subtext: Tr.tr("No screen lock or sleep while a game or video is fullscreen")
            checked: HyprSettings.saved.fullscreenInhibit ?? false
            onToggled: HyprSettings.setFullscreenInhibit(checked)
        }

        ToggleRow {
            disabled: HyprSettings.values["plugin:hyprscrolling:fullscreen_screen_sized"] === undefined
            text: Tr.tr("Games open fullscreen")
            subtext: HyprSettings.values["plugin:hyprscrolling:fullscreen_screen_sized"] === undefined ? Tr.tr("Needs the hyprscroller plugin (the scrolling layout)") : Tr.tr("Older games that open at the screen's size go fullscreen instead of into a column")
            checked: HyprSettings.value("plugin:hyprscrolling:fullscreen_screen_sized", false)
            onToggled: HyprSettings.setOption("plugin:hyprscrolling:fullscreen_screen_sized", checked ? 1 : 0)
        }

        NavRow {
            icon: "monitor"
            text: Tr.tr("Variable refresh rate")
            subtext: Tr.tr("FreeSync / G-Sync, on Display")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "display"),
                path: [],
                text: Tr.tr("Variable refresh rate")
            })
        }

        NavRow {
            icon: "notifications"
            text: Tr.tr("Notifications over fullscreen apps")
            subtext: Tr.tr("On Notifications")
            onClicked: root.nState.goTo({
                page: PageRegistry.pages.findIndex(p => p.id === "notifications"),
                path: [],
                text: Tr.tr("Show in fullscreen")
            })
        }
    }
}
