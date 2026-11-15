pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.modules.areapicker
import qs.modules.background
import qs.modules.drawers
import qs.modules.lock
import qs.modules.nebula
import qs.modules.nexus
import qs.modules.polkit
import qs.daemons

Scope {
    id: root

    required property Lock lock

    Component.onCompleted: {
        // The shell's old Desktop clock lives on as the clock widget's digital face: if it was
        // on, the widgets come on and take it over (nebula/services/Widgets.qml adoptShellClock)
        if (GlobalConfig.background.desktopClock.enabled)
            GlobalConfig.appearance.style.desktopWidgets = true;
        Players;
        HyprSettings;
        LiveWallpaper;
        Weather.reload();
        Packages;
        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }

    Timer {
        interval: 350
        running: true
        onTriggered: {
            // Pre-warm the default Settings landing page in idle time so opening Settings is instant
            PageCompRegistry.subComp("WallpaperAndStyle.qml");
        }
    }

    Background {}

    // Nebula's desktop widgets (Settings > Style), above the wallpaper and the desktop icons
    LazyLoader {
        active: GlobalConfig.appearance.style.desktopWidgets

        NebulaDesktop {}
    }
    Drawers {}
    AreaPicker {}
    PolkitOverlay {}

    // Daemons
    Shortcuts {}
    BatteryMonitor {}
    GameMode {}
    LiveWallpaperKeys {}
    IdleInhibit {}
    IdleMonitors {
        lock: root.lock
    }
}
