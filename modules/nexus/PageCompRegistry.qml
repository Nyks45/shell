pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common
// Keep these imports: Quickshell's VFS scanner registers dynamic sub-page modules from the static import graph
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.devices
import qs.modules.nexus.pages.disks
import qs.modules.nexus.pages.gaming
import qs.modules.nexus.pages.merged
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.style
import qs.modules.nexus.pages.system
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

QtObject {
    id: root

    property var _subComps: ({})

    function subComp(relPath: string): Component {
        if (_subComps[relPath])
            return _subComps[relPath];
        const comp = Qt.createComponent(Qt.resolvedUrl(`pages/${relPath}`));
        if (comp.status === Component.Error) {
            console.warn("PageCompRegistry: failed to load", relPath, comp.errorString());
            return null;
        }
        _subComps[relPath] = comp;
        return comp;
    }

    // Ordered page and sub-page table matching PageRegistry indices
    readonly property var specs: [
        // 0: Display
        [
            "DisplayPage.qml"
        ],
        // 1: Sound
        [
            "AudioPage.qml",
            "audio/AppVolumes.qml"
        ],
        // 2: Notifications
        [
            ["services/NotificationsPage.qml", { isSubPage: false }]
        ],
        // 3: Power & sleep
        [
            "PowerPage.qml"
        ],
        // 4: Storage: drives, clean up, snapshots (0), one partition (1), a drive's health (2), one snapshot (3)
        [
            "merged/StorageAllPage.qml",
            "disks/DiskPartitionPage.qml",
            "disks/DiskHealthPage.qml",
            "SnapshotPage.qml"
        ],
        // 5: Recovery & boot (0), Firmware updates (1)
        [
            ["system/BootPage.qml", { isSubPage: false }],
            "system/FirmwareUpdatesPage.qml"
        ],
        // 6: About
        [
            "AboutPage.qml"
        ],
        // 7: Devices: Bluetooth, keyboard & mouse, lighting, fans (0), a device (1), pairing (2)
        [
            "merged/DevicesPage.qml",
            "bluetooth/BtDeviceInfo.qml",
            "bluetooth/BluetoothPairing.qml"
        ],
        // 8: Network
        [
            "NetworkPage.qml",
            "network/EthernetDetailPage.qml",
            "network/AddNetworkPage.qml",
            "network/NetworkDetailPage.qml",
            "network/AddVpnPage.qml",
            "network/AllNetworksPage.qml",
            "network/SavedNetworksPage.qml"
        ],
        // 9: Wallpaper & style
        [
            "WallpaperAndStyle.qml",
            "wallandstyle/WallpaperSelect.qml",
            "wallandstyle/WallpaperCategory.qml",
            "wallandstyle/ColourSelect.qml",
            // Live wallpapers: the list (4), one wallpaper (5), playlists (6), the Workshop (7), settings (8)
            "wallandstyle/LiveWallpaperSelect.qml",
            "wallandstyle/LiveWallpaperInfo.qml",
            "wallandstyle/LivePlaylists.qml",
            "wallandstyle/LiveWorkshop.qml",
            "wallandstyle/LiveSettings.qml",
            // The desktop widgets' own pages (9): the widgets, one widget, add one, pick an image
            "style/NebulaPages.qml"
        ],
        // 10: Fonts & themes
        [
            "merged/FontsThemesPage.qml"
        ],
        // 11: Windows (look + desktop mode + title bars + app rules)
        [
            "merged/WindowsDesktopPage.qml"
        ],
        // 12: Panels: top-level (0), dashboard (1), taskbar (2), launcher (3), taskbar tray (4), OSD (5)
        [
            "PanelsPage.qml",
            "panels/DashboardPanel.qml",
            "panels/TaskbarPanel.qml",
            "panels/LauncherPanel.qml",
            "panels/taskbar/BarTray.qml",
            "panels/OsdPanel.qml"
        ],
        // 13: Workspaces & shortcuts (+ screenshots & recording)
        [
            "merged/WorkspacesAllPage.qml"
        ],
        // 14: Apps: installed, get apps, defaults, startup (0), all apps (1), one app's launcher settings (2), one package (3)
        [
            "merged/AppsAllPage.qml",
            "apps/AllApps.qml",
            "apps/AppInfo.qml",
            "apps/PackagePage.qml"
        ],
        // 15: Gaming (0), one game (1)
        [
            "gaming/GamingPage.qml",
            "gaming/GamePage.qml"
        ],
        // 16: Account: you and the others (0), another person's account (1)
        [
            "AccountPage.qml",
            "system/UserPage.qml"
        ],
        // 17: Time & language
        [
            "merged/TimeLanguagePage.qml"
        ],
        // 18: Accessibility
        [
            "AccessibilityPage.qml"
        ],
        // 19: Privacy & security
        [
            "PrivacyPage.qml"
        ],
        // 20: Updates (0), one package (1)
        [
            "UpdatesPage.qml",
            "apps/PackagePage.qml"
        ],
        // 21: Advanced: services, logs, kernels, performance, plugins (0), one service (1)
        [
            "merged/AdvancedPage.qml",
            "system/ServicePage.qml"
        ]
    ]

    readonly property Component stackPageComp: Component {
        StackPage {}
    }

    readonly property Component placeholderComp: Component {
        PlaceholderComp {}
    }

    component PlaceholderComp: Item {
        property NexusState nState // To avoid the warning from non-existent property

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.palette.m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Page under construction")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("This page will be available in a future update.")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
