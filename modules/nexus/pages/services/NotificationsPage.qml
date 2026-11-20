pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property bool hasLaptopBattery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
    property string appQuery

    function resolveApp(appName: string, savedIcon: string): var {
        const lower = (appName ?? "").toLowerCase();
        let entry = DesktopEntries.heuristicLookup(appName);
        if (!entry && lower)
            entry = [...DesktopEntries.applications.values].find(a => a.id.toLowerCase() === lower || a.name.toLowerCase() === lower) ?? null;
        return {
            title: entry?.name || appName,
            icon: Quickshell.iconPath(savedIcon || entry?.icon || "", "application-x-executable")
        };
    }

    readonly property var allApps: {
        const apps = Object.assign({}, NotifRules.seen);
        for (const n of Notifs.list)
            if (n.appName && !(n.appName in apps))
                apps[n.appName] = n.appIcon ?? "";
        return Object.entries(apps).map(([app, savedIcon]) => {
            const info = resolveApp(app, savedIcon);
            return {
                app,
                title: info.title,
                icon: info.icon
            };
        }).sort((a, b) => a.title.localeCompare(b.title));
    }

    readonly property var filteredApps: {
        const q = appQuery.trim().toLowerCase();
        if (!q)
            return allApps;
        return allApps.filter(a => a.title.toLowerCase().includes(q) || a.app.toLowerCase().includes(q));
    }

    title: Tr.tr("Notifications")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Do not disturb")
        }

        ToggleRow {
            text: Tr.tr("Do not disturb")
            subtext: Tr.tr("Silences popup notifications; they still wait in the notification list")
            checked: PersistentState.doNotDisturb
            onToggled: PersistentState.doNotDisturb = checked
        }

        SelectRow {
            id: fullscreenRow

            label: Tr.tr("Over fullscreen apps")
            subtext: Tr.tr("How notifications appear while a game or video is fullscreen")
            segmentedAllowed: false
            menuItems: [
                MenuItem {
                    text: Tr.tr("Show")
                    icon: "notifications"
                    value: "show"
                },
                MenuItem {
                    text: Tr.tr("Show briefly (2 s)")
                    icon: "notifications_paused"
                    value: "brief"
                },
                MenuItem {
                    text: Tr.tr("Hide")
                    icon: "notifications_off"
                    value: "off"
                }
            ]
            active: {
                const mode = GlobalConfig.notifs.fullscreen === NotifsFullscreen.Off
                    ? "off"
                    : (GlobalConfig.notifs.fullscreenExpireTimeout === 2000 ? "brief" : "show");
                return menuItems.find(i => i.value === mode) ?? null;
            }
            onSelected: item => {
                if (item.value === "off") {
                    GlobalConfig.notifs.fullscreen = NotifsFullscreen.Off;
                } else {
                    GlobalConfig.notifs.fullscreen = NotifsFullscreen.On;
                    GlobalConfig.notifs.fullscreenExpireTimeout = item.value === "brief" ? 2000 : GlobalConfig.notifs.defaultExpireTimeout;
                }
            }
        }

        SectionHeader {
            text: Tr.tr("General")
        }

        SelectRow {
            label: Tr.tr("Dismiss notifications after")
            subtext: Tr.tr("How long popup banners stay on screen")
            menuItems: [
                MenuItem {
                    text: Tr.tr("3 seconds")
                    value: 3000
                },
                MenuItem {
                    text: Tr.tr("5 seconds")
                    value: 5000
                },
                MenuItem {
                    text: Tr.tr("10 seconds")
                    value: 10000
                },
                MenuItem {
                    text: Tr.tr("15 seconds")
                    value: 15000
                },
                MenuItem {
                    text: Tr.tr("30 seconds")
                    value: 30000
                },
                MenuItem {
                    text: Tr.tr("Never")
                    value: 0
                }
            ]
            active: {
                const target = GlobalConfig.notifs.expire ? GlobalConfig.notifs.defaultExpireTimeout : 0;
                return menuItems.find(i => i.value === target) ?? null;
            }
            fallbackText: GlobalConfig.notifs.expire ? Tr.tr("%1 seconds").arg((GlobalConfig.notifs.defaultExpireTimeout / 1000).toFixed(GlobalConfig.notifs.defaultExpireTimeout % 1000 === 0 ? 0 : 1)) : Tr.tr("Never")
            onSelected: item => {
                if (item.value === 0) {
                    GlobalConfig.notifs.expire = false;
                } else {
                    GlobalConfig.notifs.expire = true;
                    GlobalConfig.notifs.defaultExpireTimeout = item.value;
                    if (GlobalConfig.notifs.fullscreenExpireTimeout !== 2000)
                        GlobalConfig.notifs.fullscreenExpireTimeout = item.value;
                }
            }
        }

        ToggleRow {
            text: Tr.tr("Open expanded")
            subtext: Tr.tr("Show notifications expanded by default")
            checked: GlobalConfig.notifs.openExpanded
            onToggled: GlobalConfig.notifs.openExpanded = checked
        }

        ToggleRow {
            text: Tr.tr("Click to open")
            subtext: Tr.tr("Clicking a notification does its main action, e.g. opens the message")
            checked: GlobalConfig.notifs.actionOnClick
            onToggled: GlobalConfig.notifs.actionOnClick = checked
        }

        StepperRow {
            label: Tr.tr("Group preview count")
            subtext: Tr.tr("Notifications shown per group before collapsing")
            value: GlobalConfig.notifs.groupPreviewNum
            from: 1
            to: 10
            stepSize: 1
            onMoved: v => GlobalConfig.notifs.groupPreviewNum = Math.round(v)
        }

        NavRow {
            icon: "music_note"
            text: Tr.tr("Notification sound")
            subtext: NotifRules.sound ? Tr.tr("On · configure on Sound") : Tr.tr("Off · configure on Sound")
            onClicked: root.nState.goTo({
                page: PageRegistry.find("audio"),
                path: [],
                text: Tr.tr("Notification sound"),
                sectionText: Tr.tr("Sounds")
            })
        }

        // Per app (NotifRules): above Shell messages so app controls are easy to find
        SectionHeader {
            text: Tr.tr("Apps")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            text: root.allApps.length === 0 ? Tr.tr("Apps show up here once they've sent a notification.") : Tr.tr("Quiet: kept in the notification list, without a popup. Off: not shown at all.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        SearchBar {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.allApps.length > 4
            placeholderText: Tr.tr("Search apps")
            onTextChanged: root.appQuery = text
        }

        Repeater {
            id: appList

            model: root.filteredApps

            ConnectedRect {
                id: appRow

                required property var modelData
                required property int index
                readonly property string mode: NotifRules.mode(modelData.app)

                Layout.fillWidth: true
                implicitHeight: appRowLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: appRowLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    ThemedIcon {
                        Layout.alignment: Qt.AlignVCenter
                        asynchronous: true
                        monochrome: true
                        implicitSize: 22
                        source: appRow.modelData.icon
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: appRow.modelData.title
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: appRow.mode === "off" ? Tr.tr("Off") : appRow.mode === "quiet" ? Tr.tr("Quiet") : ""
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    SplitButton {
                        id: appSplit

                        type: SplitButton.Tonal
                        menuOnTop: appRow.index >= Math.max(0, appList.count - 2)
                        stateLayer.onClicked: appSplit.expanded = !appSplit.expanded
                        menuItems: [
                            MenuItem {
                                text: Tr.tr("Show")
                                icon: "notifications"
                                value: "all"
                            },
                            MenuItem {
                                text: Tr.tr("Quiet")
                                icon: "notifications_paused"
                                value: "quiet"
                            },
                            MenuItem {
                                text: Tr.trCtx("Off", "notifications from one app")
                                icon: "notifications_off"
                                value: "off"
                            }
                        ]
                        active: menuItems.find(i => i.value === NotifRules.mode(appRow.modelData.app)) ?? menuItems[0]
                        menu.onItemSelected: item => {
                            NotifRules.setMode(appRow.modelData.app, item.value);
                            appSplit.active = Qt.binding(() => appSplit.menuItems.find(i => i.value === NotifRules.mode(appRow.modelData.app)) ?? appSplit.menuItems[0]);
                        }
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        onClicked: NotifRules.forget(appRow.modelData.app)
                    }
                }
            }
        }

        // Toast events (the shell's own messages)
        SectionHeader {
            text: Tr.tr("Shell messages")
        }

        ToggleRow {
            visible: root.hasLaptopBattery
            text: Tr.tr("Charging changes")
            checked: GlobalConfig.utilities.toasts.chargingChanged
            onToggled: GlobalConfig.utilities.toasts.chargingChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Game mode changes")
            checked: GlobalConfig.utilities.toasts.gameModeChanged
            onToggled: GlobalConfig.utilities.toasts.gameModeChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Do not disturb changes")
            checked: GlobalConfig.utilities.toasts.dndChanged
            onToggled: GlobalConfig.utilities.toasts.dndChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Audio output changes")
            checked: GlobalConfig.utilities.toasts.audioOutputChanged
            onToggled: GlobalConfig.utilities.toasts.audioOutputChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Audio input changes")
            checked: GlobalConfig.utilities.toasts.audioInputChanged
            onToggled: GlobalConfig.utilities.toasts.audioInputChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Caps lock changes")
            checked: GlobalConfig.utilities.toasts.capsLockChanged
            onToggled: GlobalConfig.utilities.toasts.capsLockChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Num lock changes")
            checked: GlobalConfig.utilities.toasts.numLockChanged
            onToggled: GlobalConfig.utilities.toasts.numLockChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Keyboard layout changes")
            checked: GlobalConfig.utilities.toasts.kbLayoutChanged
            onToggled: GlobalConfig.utilities.toasts.kbLayoutChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Keyboard layout limit reached")
            checked: GlobalConfig.utilities.toasts.kbLimit
            onToggled: GlobalConfig.utilities.toasts.kbLimit = checked
        }

        ToggleRow {
            text: Tr.tr("VPN changes")
            checked: GlobalConfig.utilities.toasts.vpnChanged
            onToggled: GlobalConfig.utilities.toasts.vpnChanged = checked
        }

        ToggleRow {
            text: Tr.tr("Now playing")
            checked: GlobalConfig.utilities.toasts.nowPlaying
            onToggled: GlobalConfig.utilities.toasts.nowPlaying = checked
        }
    }
}
