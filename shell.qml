//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

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

ShellRoot {
    id: root

    settings.watchFiles: true

    Component.onCompleted: {
        // Critical singletons needed on Frame 0
        Notifs;
        Brightness;
        LiveStartFrame;
        Polkit;
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            Players;
            HyprSettings;
            LiveWallpaper;
            Weather.reload();
            Packages;
            if (GlobalConfig.utilities.vpn.enabled)
                VPN;
        }
    }

    Timer {
        interval: 550
        running: true
        onTriggered: {
            // Pre-warm the default Settings landing page in idle time so opening Settings is instant
            PageCompRegistry.subComp("WallpaperAndStyle.qml");
        }
    }

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Modules
    Background {}
    Drawers {}
    AreaPicker {}
    PolkitOverlay {}
    Lock {
        id: lock
    }

    // Daemons
    Shortcuts {}
    BatteryMonitor {}
    GameMode {}
    LiveWallpaperKeys {}
    IdleInhibit {}
    IdleMonitors {
        lock: lock
    }
}
