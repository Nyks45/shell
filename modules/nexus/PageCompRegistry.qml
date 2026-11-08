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
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.system
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

QtObject {
    id: root

    readonly property list<Component> pageComps: [
        // Appearance
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
            // Fonts
            StackPage {
                Component {
                    FontsPage {}
                }
            }
        },
        Component {
            // App appearance
            StackPage {
                Component {
                    AppAppearancePage {}
                }
            }
        },
        Component {
            // Windows
            StackPage {
                Component {
                    WindowsPage {}
                }
            }
        },
        Component {
            // Desktop mode
            StackPage {
                Component {
                    DesktopModePage {}
                }
            }
        },

        // Connectivity
        Component {
            // Display
            StackPage {
                Component {
                    DisplayPage {}
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
            // Bluetooth
            StackPage {
                Component {
                    BluetoothPage {}
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
            // Printers
            StackPage {
                Component {
                    PrintersPage {}
                }
            }
        },

        // System
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
            // Power & sleep
            StackPage {
                Component {
                    PowerPage {}
                }
            }
        },
        Component {
            // Keyboard & mouse
            StackPage {
                Component {
                    InputPage {}
                }
            }
        },
        Component {
            // Workspaces & focus
            StackPage {
                Component {
                    MultitaskingPage {}
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
            // Date & time
            StackPage {
                Component {
                    DateTimePage {}
                }
            }
        },
        Component {
            // Storage: the page with its drives (0), one partition (1), a drive's health details (2)
            StackPage {
                Component {
                    StoragePage {}
                }
                Component {
                    DiskPartitionPage {}
                }
                Component {
                    DiskHealthPage {}
                }
            }
        },
        Component {
            // Backups: the snapshots (0), one snapshot (1)
            StackPage {
                Component {
                    BackupsPage {}
                }
                Component {
                    SnapshotPage {}
                }
            }
        },
        Component {
            // Screenshots & recording
            StackPage {
                Component {
                    ScreenshotsPage {}
                }
            }
        },
        Component {
            // Startup apps
            StackPage {
                Component {
                    StartupPage {}
                }
            }
        },
        Component {
            // Keyboard shortcuts
            StackPage {
                Component {
                    ShortcutsPage {}
                }
            }
        },
        Component {
            // Updates
            StackPage {
                Component {
                    UpdatesPage {}
                }
            }
        },
        Component {
            // System services: the list (0), one service or scheduled task (1)
            StackPage {
                Component {
                    SystemServicesPage {}
                }
                Component {
                    ServicePage {}
                }
            }
        },
        Component {
            // Logs
            StackPage {
                Component {
                    LogsPage {}
                }
            }
        },
        Component {
            // Plugins
            StackPage {
                Component {
                    PluginsPage {}
                }
            }
        },

        // Accessibility & privacy
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

        // Shell
        Component {
            // Panels
            StackPage {
                Component {
                    PanelsPage {}
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
            // Apps
            StackPage {
                Component {
                    AppsPage {}
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
            // Services
            StackPage {
                Component {
                    ServicesPage {}
                }
                Component {
                    NotificationsPage {}
                }
            }
        },
        Component {
            // Language & region
            StackPage {
                Component {
                    LanguageAndRegion {}
                }
            }
        },

        // About
        Component {
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
