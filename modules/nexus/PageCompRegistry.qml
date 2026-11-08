pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.disks
import qs.modules.nexus.pages.merged
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.system
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

QtObject {
    id: root

    readonly property list<Component> pageComps: [
        Component {
            // Wallpaper & style
            StackPage {
                Component {
                    WallpaperAndStyle {}
                }
                Component {
                    WallpaperSelect {}
                }
                Component {
                    WallpaperCategory {}
                }
                Component {
                    ColourSelect {}
                }
                // Live wallpapers: the list (4), one wallpaper (5), playlists (6), the Workshop (7), settings (8)
                Component {
                    LiveWallpaperSelect {}
                }
                Component {
                    LiveWallpaperInfo {}
                }
                Component {
                    LivePlaylists {}
                }
                Component {
                    LiveWorkshop {}
                }
                Component {
                    LiveSettings {}
                }
            }
        },
        Component {
            // Fonts & themes
            StackPage {
                Component {
                    FontsThemesPage {}
                }
            }
        },
        Component {
            // Windows (look + desktop mode)
            StackPage {
                Component {
                    WindowsDesktopPage {}
                }
            }
        },
        Component {
            // Panels (+ shell services, folded)
            StackPage {
                Component {
                    PanelsAllPage {}
                }
                Component {
                    DashboardPanel {}
                }
                Component {
                    TaskbarPanel {}
                }
                Component {
                    LauncherPanel {}
                }
                Component {
                    SidebarPanel {}
                }
                Component {
                    UtilitiesPanel {}
                }

                // Taskbar component sub-pages
                Component {
                    BarWorkspaces {}
                }
                Component {
                    BarActiveWindow {}
                }
                Component {
                    BarTray {}
                }
                Component {
                    BarStatusIcons {}
                }
                Component {
                    BarClock {}
                }

                // Other panels (after the taskbar ones: their indices stay)
                Component {
                    LockPanel {}
                }
                Component {
                    OsdPanel {}
                }
                Component {
                    SessionPanel {}
                }
            }
        },
        Component {
            // Display
            StackPage {
                Component {
                    DisplayPage {}
                }
            }
        },
        Component {
            // Audio
            StackPage {
                Component {
                    AudioPage {}
                }
                Component {
                    AppVolumes {}
                }
            }
        },
        Component {
            // Notifications
            StackPage {
                Component {
                    NotificationsPage { isSubPage: false }
                }
            }
        },
        Component {
            // Power & sleep
            StackPage {
                Component {
                    PowerPage {}
                }
            }
        },
        Component {
            // Storage: the page (drives, clean up, snapshots) (0), one partition (1), a drive's health (2), one snapshot (3)
            StackPage {
                Component {
                    StorageAllPage {}
                }
                Component {
                    DiskPartitionPage {}
                }
                Component {
                    DiskHealthPage {}
                }
                Component {
                    SnapshotPage {}
                }
            }
        },
        Component {
            // Devices: Bluetooth + keyboard & mouse (0), a device (1), pairing (2)
            StackPage {
                Component {
                    DevicesPage {}
                }
                Component {
                    BtDeviceInfo {}
                }
                Component {
                    BluetoothPairing {}
                }
            }
        },
        Component {
            // Network
            StackPage {
                Component {
                    NetworkPage {}
                }
                Component {
                    EthernetDetailPage {}
                }
                Component {
                    AddNetworkPage {}
                }
                Component {
                    NetworkDetailPage {}
                }
                Component {
                    AddVpnPage {}
                }
                Component {
                    AllNetworksPage {}
                }
                Component {
                    SavedNetworksPage {}
                }
            }
        },
        Component {
            // Apps: updates, apps, startup apps (0), all apps (1), one app (2)
            StackPage {
                Component {
                    AppsAllPage {}
                }
                Component {
                    AllApps {}
                }
                Component {
                    AppInfo {}
                }
            }
        },
        Component {
            // Workspaces & shortcuts (+ screenshots & recording)
            StackPage {
                Component {
                    WorkspacesAllPage {}
                }
            }
        },
        Component {
            // Account: you and the others (0), another person's account (1)
            StackPage {
                Component {
                    AccountPage {}
                }
                Component {
                    UserPage {}
                }
            }
        },
        Component {
            // Time & language
            StackPage {
                Component {
                    TimeLanguagePage {}
                }
            }
        },
        Component {
            // Accessibility
            StackPage {
                Component {
                    AccessibilityPage {}
                }
            }
        },
        Component {
            // Privacy & security
            StackPage {
                Component {
                    PrivacyPage {}
                }
            }
        },
        Component {
            // Gaming
            StackPage {
                Component {
                    GamingPage {}
                }
            }
        },
        Component {
            // System: services (+ logs, plugins, folded) (0), one service (1)
            StackPage {
                Component {
                    SystemPage {}
                }
                Component {
                    ServicePage {}
                }
            }
        },
        Component {
            // About
            StackPage {
                Component {
                    AboutPage {}
                }
            }
        }
    ]

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
