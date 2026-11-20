pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Lyrics backends, ordered to match config::LyricsBackend (Auto, Local, LRCLIB, NetEase)
    readonly property list<MenuItem> lyricsItems: [
        MenuItem {
            text: Tr.trCtx("Auto", "lyrics backend")
        },
        MenuItem {
            text: Tr.trCtx("Local", "lyrics backend")
        },
        MenuItem {
            text: "LRCLIB"
        },
        MenuItem {
            text: "NetEase"
        }
    ]

    title: Tr.tr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Panels")
        }

        NavRow {
            icon: "dashboard"
            text: Tr.tr("Dashboard")
            subtext: Config.dashboard.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            icon: "dock_to_bottom"
            text: Tr.tr("Taskbar")
            subtext: Config.bar.persistent ? Tr.tr("Always visible") : Config.bar.showOnHover ? Tr.tr("Reveal on hover") : Tr.tr("Reveal on drag")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "apps"
            text: Tr.tr("Launcher")
            subtext: Config.launcher.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            icon: "tune"
            text: Tr.tr("On-screen display")
            subtext: Config.osd.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(5)
        }

        SectionHeader {
            text: Tr.tr("Media")
        }

        SelectRow {
            label: Tr.tr("Lyrics source")
            subtext: Tr.tr("Service used to fetch synced lyrics")
            menuItems: root.lyricsItems
            active: root.lyricsItems[Lyrics.preferredBackend] ?? root.lyricsItems[0]
            onSelected: item => Lyrics.preferredBackend = root.lyricsItems.indexOf(item)
        }

        SelectRow {
            label: Tr.tr("Default media player")
            subtext: Tr.tr("Preferred player when several are open")
            segmentedAllowed: false
            menuItems: [autoPlayer, ...playerVariants.instances]
            active: menuItems.find(i => i.value === GlobalConfig.services.defaultPlayer) ?? null
            fallbackIcon: "music_note"
            fallbackText: GlobalConfig.services.defaultPlayer || Tr.trCtx("Auto", "default media player")
            onSelected: item => GlobalConfig.services.defaultPlayer = item.value

            MenuItem {
                id: autoPlayer

                text: Tr.trCtx("Auto", "default media player")
                icon: !GlobalConfig.services.defaultPlayer ? "check" : ""
                activeIcon: "music_note"
                value: ""
            }

            // Detected running players, used as default-player options
            Variants {
                id: playerVariants

                model: [...new Set(Players.list.map(p => Players.getIdentity(p)).filter(id => id))]

                MenuItem {
                    required property string modelData

                    text: modelData
                    icon: modelData === GlobalConfig.services.defaultPlayer ? "check" : ""
                    activeIcon: "music_note"
                    value: modelData
                }
            }
        }

        // The shell's style: compact (the pill and islands) or full (the classic shell); each is
        // its own build, so switching builds and installs the other, then restarts the shell
        SectionHeader {
            text: Tr.tr("Shell")
        }

        SelectRow {
            label: Tr.tr("Shell style")
            subtext: ShellStyle.step === "building" ? Tr.tr("Building the other style… (about two minutes)") + (ShellStyle.log ? `\n${ShellStyle.log.split("\n").pop()}` : "") : ShellStyle.step === "installing" ? Tr.tr("Installing it…") : ShellStyle.error ? Tr.tr("Couldn't switch: %1").arg(ShellStyle.error) : Tr.tr("Switching installs the other one and restarts the shell")
            enabled: !ShellStyle.step
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Compact (pill)")
                    icon: "toggle_on"
                    value: "compact"
                },
                MenuItem {
                    text: Tr.tr("Full (classic)")
                    icon: "dock_to_right"
                    value: "full"
                }
            ]
            active: menuItems.find(i => i.value === ShellStyle.current) ?? menuItems[0]
            onSelected: item => ShellStyle.switchTo(item.value)
        }
    }
}
