pragma ComponentBehavior: Bound

import "mini"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus

Item {
    id: root

    required property ScreenState screenState
    readonly property var dashboardTabs: {
        const allTabs = [
            {
                key: "dashboard",
                component: dashComponent,
                iconName: "dashboard",
                text: Tr.tr("Overview"),
                enabled: Config.dashboard.showDashboard
            },
            {
                key: "media",
                component: mediaComponent,
                iconName: "queue_music",
                text: Tr.tr("Media"),
                enabled: Config.dashboard.showMedia
            },
            {
                key: "performance",
                component: performanceComponent,
                iconName: "speed",
                text: Tr.tr("Performance"),
                enabled: Config.dashboard.showPerformance
            },
            {
                key: "weather",
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            },
            {
                key: "notifications",
                component: notificationsComponent,
                iconName: "notifications",
                text: Tr.tr("Notifications"),
                enabled: true
            },
            {
                // The island's pill, clicked: quick settings
                key: "quick",
                component: quickComponent,
                iconName: "tune",
                text: Tr.tr("Quick settings"),
                enabled: true
            },
            {
                key: "wallpapers",
                component: wallpapersComponent,
                iconName: "wallpaper",
                text: Tr.tr("Wallpapers"),
                enabled: Config.dashboard.showWallpapers
            },
            {
                // The island's settings button: the settings, grown out of the pill
                key: "settings",
                component: settingsComponent,
                iconName: "settings",
                text: Tr.tr("Settings"),
                enabled: true
            },
            {
                // The island's power button: lock, sleep, log out, restart, shut down
                key: "power",
                component: powerComponent,
                iconName: "power_settings_new",
                text: Tr.tr("Power"),
                enabled: true
            }
        ];
        return allTabs.filter(tab => tab.enabled);
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    // The page shown, and whether it has the page tabs (all but the settings)
    readonly property string pageKey: dashboardTabs[screenState.dashboardTab]?.key ?? ""
    readonly property bool showJump: pageKey !== "" && pageKey !== "settings"
    // Its own size and page-slide animations, only once fully open (while the island grows or
    // shrinks, it heads straight for its size: set by Wrapper)
    property bool animateSize: true
    readonly property real nonAnimHeight: (showJump ? jump.implicitHeight + Tokens.padding.medium : 0) + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    // Jump to another page: a row of its icons (all but the settings), the one shown on a
    // highlight that slides between them (fixed sizes, so nothing shifts); a click goes there
    Item {
        id: jump

        readonly property var list: root.dashboardTabs.filter(t => t.key !== "settings")
        readonly property int current: Math.max(0, list.findIndex(t => t.key === root.pageKey))
        readonly property real cell: 40

        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.medium
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showJump
        implicitWidth: cell * list.length + 6
        implicitHeight: 34

        StyledRect {
            anchors.fill: parent
            radius: height / 2
            color: Colours.tPalette.m3surfaceContainerHigh
        }

        StyledRect {
            x: 3 + jump.current * jump.cell
            y: 3
            width: jump.cell
            height: jump.height - 6
            radius: height / 2
            color: Colours.palette.m3primary

            Behavior on x {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }

        Row {
            x: 3
            y: 3

            Repeater {
                model: jump.list

                Item {
                    id: tab

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: jump.current === index

                    width: jump.cell
                    height: jump.height - 6

                    StateLayer {
                        radius: height / 2
                        color: tab.isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: {
                            if (!tab.isCurrent)
                                root.screenState.dashboardRequest = tab.modelData.key;
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: tab.modelData.key === "quick" ? "tune" : tab.modelData.iconName
                        color: tab.isCurrent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                        fill: tab.isCurrent ? 1 : 0

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }
            }
        }
    }

    ClipRect {
        id: viewWrapper

        anchors.top: root.showJump ? jump.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        radius: Tokens.rounding.large
        color: "transparent"

        // One page at a time (the island opens a page alone): a single slot, sized by its page
        Item {
            id: view

            readonly property int currentIndex: root.screenState.dashboardTab
            readonly property Item currentItem: page.item

            anchors.fill: parent
            implicitWidth: page.item?.implicitWidth ?? 0
            implicitHeight: page.item?.implicitHeight ?? 0

            Loader {
                id: page

                width: parent.width
                height: parent.height
                sourceComponent: root.dashboardTabs[view.currentIndex]?.component ?? null
            }

            // Switching pages: the new one slides in from the side of its tab and fades in
            property int shownIndex: currentIndex
            onCurrentIndexChanged: {
                const dir = currentIndex > shownIndex ? 1 : -1;
                shownIndex = currentIndex;
                if (root.animateSize) {
                    switchAnim.from = dir * 40;
                    switchAnim.restart();
                    fadeAnim.restart();
                }
            }

            Anim {
                id: switchAnim

                target: page
                property: "x"
                to: 0
                type: Anim.DefaultSpatial
            }

            Anim {
                id: fadeAnim

                target: page
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }

            Component {
                id: dashComponent

                MiniOverview {
                    screenState: root.screenState
                }
            }

            Component {
                id: mediaComponent

                MiniMedia {
                    screenState: root.screenState
                }
            }

            Component {
                id: performanceComponent

                MiniPerformance {}
            }

            Component {
                id: weatherComponent

                MiniWeather {}
            }

            Component {
                id: settingsComponent

                ClipRect {
                    readonly property var scr: (QsWindow.window as QsWindow)?.screen ?? null

                    radius: Tokens.rounding.extraLarge
                    // Never wider or taller than the screen (a portrait screen, a small one)
                    implicitWidth: Math.min(nexusInner.implicitWidth, (scr?.width ?? 1920) - Tokens.padding.extraLarge * 4)
                    implicitHeight: Math.min(nexusInner.implicitHeight, (scr?.height ?? 1080) - Tokens.padding.extraLarge * 4)

                    Nexus {
                        id: nexusInner

                        // Opened at a page (the quick settings' "open in settings"): go there
                        function showRequested(): void {
                            const id = root.screenState.dashboardSettingsPage;
                            if (!id)
                                return;
                            const t = PageRegistry.target(id);
                            nState.goTo({
                                page: Math.max(0, t.page),
                                path: [],
                                tab: t.tab
                            });
                            root.screenState.dashboardSettingsPage = "";
                        }

                        anchors.fill: parent
                        nState.screen: (QsWindow.window as QsWindow)?.screen ?? null
                        onClose: root.screenState.dashboard = false
                        Component.onCompleted: showRequested()

                        Connections {
                            function onDashboardSettingsPageChanged(): void {
                                nexusInner.showRequested();
                            }

                            target: root.screenState
                        }
                    }

                    Shortcut {
                        sequence: "Escape"
                        onActivated: root.screenState.dashboard = false
                    }
                }
            }

            Component {
                id: powerComponent

                MiniPower {}
            }

            Component {
                id: quickComponent

                MiniQuick {
                    screenState: root.screenState
                    fixedPane: 0
                }
            }

            Component {
                id: notificationsComponent

                MiniQuick {
                    screenState: root.screenState
                    fixedPane: 1
                }
            }

            Component {
                id: wallpapersComponent

                WallpapersTab {
                    screenState: root.screenState
                }
            }

        }
    }

    Behavior on implicitWidth {
        enabled: root.animateSize

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.animateSize

        Anim {}
    }
}
