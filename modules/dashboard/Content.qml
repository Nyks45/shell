pragma ComponentBehavior: Bound

import "mini"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.utils

Item {
    id: root

    required property ScreenState screenState
    readonly property FileDialog facePicker: FileDialog {
        title: Tr.tr("Select a profile picture")
        filterLabel: Tr.tr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(Paths.face)) && (Paths.reloadFace(), true))
                // TRANSLATORS: %1 = a file path
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${path}`, Tr.tr("Profile picture changed"), Tr.tr("Profile picture changed to %1").arg(Paths.shortenHome(path))]);
            else
                // TRANSLATORS: %1 = a file path
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", Tr.tr("Unable to change profile picture"), Tr.tr("Failed to change profile picture to %1").arg(Paths.shortenHome(path))]);
        }
    }

    readonly property var dashboardTabs: {
        const allTabs = [
            {
                component: dashComponent,
                iconName: "dashboard",
                text: Tr.tr("Dashboard"),
                enabled: Config.dashboard.showDashboard
            },
            {
                component: mediaComponent,
                iconName: "queue_music",
                text: Tr.tr("Media"),
                enabled: Config.dashboard.showMedia
            },
            {
                component: performanceComponent,
                iconName: "speed",
                text: Tr.tr("Performance"),
                enabled: Config.dashboard.showPerformance
            },
            {
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            },
            {
                component: wallpapersComponent,
                iconName: "wallpaper",
                text: Tr.tr("Wallpapers"),
                enabled: Config.dashboard.showWallpapers
            },
            {
                // The island's pill, clicked: quick settings and notifications
                component: quickComponent,
                iconName: "tune",
                text: Tr.tr("Quick settings"),
                enabled: true
            }
        ];
        return allTabs.filter(tab => tab.enabled);
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    // One page alone (the island's buttons): no tabs
    readonly property bool solo: true // one page at a time, opened from the island (Wrapper.qml)
    // Its own size and page-slide animations, only once fully open (while the island grows or
    // shrinks, it heads straight for its size: set by Wrapper)
    property bool animateSize: true
    readonly property real nonAnimHeight: (solo ? 0 : tabs.implicitHeight + tabs.anchors.topMargin) + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: CUtils.clamp(anchors.margins - Config.border.thickness, 0, anchors.margins)
        anchors.margins: Tokens.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        screenState: root.screenState
        tabs: root.dashboardTabs
        visible: !root.solo
    }

    ClipRect {
        id: viewWrapper

        anchors.top: root.solo ? parent.top : tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        radius: Tokens.rounding.large
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.screenState.dashboardTab
            readonly property Item currentItem: {
                CUtils.dependency(repeater.count); // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick
            // One page alone: no swiping to the others
            interactive: !root.solo

            implicitWidth: currentItem?.implicitWidth ?? 0
            implicitHeight: currentItem?.implicitHeight ?? 0

            contentX: currentItem?.x ?? 0
            // At least up to the page shown: a page opened directly (the island's buttons) isn't
            // built yet, and past the end the view would snap back to the first page
            contentWidth: Math.max(row.implicitWidth, (currentItem?.x ?? 0) + width)
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem?.x ?? 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: repeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        Layout.alignment: Qt.AlignTop

                        sourceComponent: modelData.component

                        active: {
                            if (index === view.currentIndex)
                                return true;
                            if (view.moving && Math.abs(index - view.currentIndex) <= 1)
                                return true;
                            if (view.contentWidth <= 0 || implicitWidth <= 0)
                                return false;
                            const vx = Math.floor(view.visibleArea.xPosition * view.contentWidth);
                            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth);
                            return (vx >= x && vx <= x + implicitWidth) || (vex >= x && vex <= x + implicitWidth);
                        }
                    }
                }
            }

            Component {
                id: dashComponent

                MiniOverview {}
            }

            Component {
                id: mediaComponent

                MiniMedia {}
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
                id: quickComponent

                MiniQuick {}
            }

            Component {
                id: wallpapersComponent

                WallpapersTab {
                    screenState: root.screenState
                }
            }

            Behavior on contentX {
                enabled: root.animateSize

                Anim {}
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
