pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.modules.areapicker
import qs.modules.background
import qs.modules.drawers
import qs.modules.lock
import qs.modules.nexus
import qs.modules.polkit
import qs.daemons

Scope {
    id: root

    required property Lock lock

    Component.onCompleted: {
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
