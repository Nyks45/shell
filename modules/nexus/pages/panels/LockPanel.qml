pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    property bool hasFprint
    property bool hasHowdy

    title: Tr.tr("Lock screen")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Look")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Wallpaper as background")
            subtext: Tr.tr("Otherwise a plain colour")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        ToggleRow {
            text: Tr.tr("Colour the logo")
            subtext: Tr.tr("In the wallpaper's colours")
            checked: Config.lock.recolourLogo
            onToggled: GlobalConfig.lock.recolourLogo = checked
        }

        ToggleRow {
            text: Tr.tr("Hide notifications")
            subtext: Tr.tr("Nothing from them shows while locked")
            checked: Config.lock.hideNotifs
            onToggled: GlobalConfig.lock.hideNotifs = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Power buttons")
            subtext: Tr.tr("Shut down, restart and sleep from the lock screen")
            checked: Config.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        SectionHeader {
            visible: root.hasFprint || root.hasHowdy
            text: Tr.tr("Unlocking")
        }

        ToggleRow {
            visible: root.hasFprint
            first: true
            last: !root.hasHowdy
            text: Tr.tr("Fingerprint")
            checked: Config.lock.enableFprint
            onToggled: GlobalConfig.lock.enableFprint = checked
        }

        ToggleRow {
            visible: root.hasHowdy
            first: !root.hasFprint
            last: true
            text: Tr.tr("Face (Howdy)")
            checked: Config.lock.enableHowdy
            onToggled: GlobalConfig.lock.enableHowdy = checked
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            running: true
            command: ["sh", "-c", "command -v fprintd-verify >/dev/null && echo FPRINT; command -v howdy >/dev/null && echo HOWDY"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.hasFprint = text.includes("FPRINT");
                    root.hasHowdy = text.includes("HOWDY");
                }
            }
        }
    }
}
