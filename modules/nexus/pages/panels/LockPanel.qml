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
    property bool checked

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
            text: Tr.tr("Wallpaper as background")
            subtext: Tr.tr("Otherwise a plain colour")
            checked: GlobalConfig.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        ToggleRow {
            text: Tr.tr("Colour the logo")
            subtext: Tr.tr("In the wallpaper's colours")
            checked: GlobalConfig.lock.recolourLogo
            onToggled: GlobalConfig.lock.recolourLogo = checked
        }

        ToggleRow {
            text: Tr.tr("Hide notifications")
            subtext: Tr.tr("Nothing from them shows while locked")
            checked: GlobalConfig.lock.hideNotifs
            onToggled: GlobalConfig.lock.hideNotifs = checked
        }

        ToggleRow {
            text: Tr.tr("Power buttons")
            subtext: Tr.tr("Shut down, restart and sleep from the lock screen")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        SectionHeader {
            text: Tr.tr("Unlocking")
        }

        RequirementRow {
            visible: root.checked && !root.hasFprint && !root.hasHowdy
            icon: "fingerprint"
            text: Tr.tr("Only the password unlocks this PC")
            subtext: Tr.tr("Fingerprint unlock needs fprintd and a fingerprint reader; face unlock needs Howdy and an infrared camera.")
        }

        ToggleRow {
            visible: root.hasFprint
            text: Tr.tr("Fingerprint")
            checked: GlobalConfig.lock.enableFprint
            onToggled: GlobalConfig.lock.enableFprint = checked
        }

        StepperRow {
            visible: root.hasFprint && GlobalConfig.lock.enableFprint
            label: Tr.tr("Fingerprint attempts")
            subtext: Tr.tr("Then it asks for the password")
            value: GlobalConfig.lock.maxFprintTries
            from: 1
            to: 10
            stepSize: 1
            onMoved: v => GlobalConfig.lock.maxFprintTries = v
        }

        ToggleRow {
            visible: root.hasHowdy
            text: Tr.tr("Face (Howdy)")
            checked: GlobalConfig.lock.enableHowdy
            onToggled: GlobalConfig.lock.enableHowdy = checked
        }

        ToggleRow {
            visible: root.hasHowdy && GlobalConfig.lock.enableHowdy
            text: Tr.tr("Look for a face on wake")
            subtext: Tr.tr("Face unlock starts as soon as the screen comes on")
            checked: GlobalConfig.lock.triggerHowdyOnWake
            onToggled: GlobalConfig.lock.triggerHowdyOnWake = checked
        }

        StepperRow {
            visible: root.hasHowdy && GlobalConfig.lock.enableHowdy
            label: Tr.tr("Face attempts")
            value: GlobalConfig.lock.maxHowdyTries
            from: 1
            to: 10
            stepSize: 1
            onMoved: v => GlobalConfig.lock.maxHowdyTries = v
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            running: true
            command: ["sh", "-c", "command -v fprintd-verify >/dev/null && echo FPRINT; command -v howdy >/dev/null && echo HOWDY"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.hasFprint = text.includes("FPRINT");
                    root.hasHowdy = text.includes("HOWDY");
                    root.checked = true;
                }
            }
        }
    }
}
