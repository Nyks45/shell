//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.modules
import qs.modules.lock

ShellRoot {
    id: root

    property bool desktopReady: !lockController.startLocked

    settings.watchFiles: true

    function loadDesktop(): void {
        if (!desktopReady || desktopLoader.active || desktopLoader.loading)
            return;
        if (lockController.startLocked)
            desktopLoader.activeAsync = true;
        else
            desktopLoader.active = true;
    }

    onDesktopReadyChanged: loadDesktop()

    Connections {
        target: lockController.lock

        function onSecureChanged(): void {
            if (lockController.lock.secure && !root.desktopReady)
                bootDesktopDelay.restart();
        }
    }

    Timer {
        id: bootDesktopDelay

        interval: 750
        onTriggered: root.desktopReady = true
    }

    Timer {
        interval: 2200
        running: lockController.startLocked && !root.desktopReady
        onTriggered: root.desktopReady = true
    }

    Component.onCompleted: {
        // Non-boot sessions instantiate desktop modules right away; boot-lock starts Lock first.
        if (desktopReady)
            loadDesktop();
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            Notifs;
            Brightness;
            LiveStartFrame;
            Polkit;
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

    // Lock first so cold-boot --locked-cmd renders Frame 0 before instantiating desktop modules
    Lock {
        id: lockController
    }

    LazyLoader {
        id: desktopLoader

        DesktopShell {
            lock: lockController
        }
    }
}
