pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.modules.areapicker
import qs.modules.background
import qs.modules.bluetooth
import qs.modules.drawers
import qs.modules.lock
import qs.modules.desktopwidgets
import qs.modules.nexus
import qs.modules.polkit
import qs.modules.taskmanager
import qs.daemons

Scope {
    id: root

    required property Lock lock

    Component.onCompleted: {
        // The shell's old Desktop clock lives on as the clock widget's digital face: if it was
        // on, the widgets come on and take it over (widgets/services/Widgets.qml adoptShellClock)
        if (GlobalConfig.background.desktopClock.enabled)
            GlobalConfig.appearance.style.desktopWidgets = true;
        Players;
        HyprSettings;
        LiveWallpaper;
        Weather.reload();
        Packages;
        BluetoothAgent;
        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }

    Timer {
        interval: 350
        running: true
        onTriggered: {
            // Pre-warm the default Settings landing page in idle time so opening Settings is instant
            PageCompRegistry.subComp("DisplayPage.qml");
        }
    }

    Background {}
    LiveWallpaperTransition {}

    // The desktop widgets (Settings > Wallpaper & style > Desktop), above the wallpaper and the desktop icons
    LazyLoader {
        active: GlobalConfig.appearance.style.desktopWidgets

        DesktopWidgets {}
    }
    Drawers {}
    AreaPicker {}
    PolkitOverlay {}
    BluetoothAgentOverlay {}
    TaskManager {}

    // Daemons
    Shortcuts {}
    BatteryMonitor {}
    GameMode {}
    LiveWallpaperKeys {}
    LightingAccent {}
    IdleInhibit {}
    IdleMonitors {
        lock: root.lock
    }
}
