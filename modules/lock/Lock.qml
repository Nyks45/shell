pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components.misc

Scope {
    id: root

    property alias lock: lock
    readonly property bool startLocked: Quickshell.env("CAELESTIA_BOOT_LOCK") === "1"
    property bool bootLockActive: startLocked

    WlSessionLock {
        id: lock

        signal unlock

        locked: root.startLocked

        onLockedChanged: {
            if (!locked)
                root.bootLockActive = false;
        }

        LockSurface {
            lock: lock
            pam: pam
            bootLock: root.bootLockActive
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    Loader {
        asynchronous: true
        active: !GlobalConfig.lock.useWallpaper && !root.startLocked
        onLoaded: active = false

        // Force a load of a screencopy so the one in the lock works
        // My guess is the ICC backend loads async on first request, which if the lock is
        // the first request it fails to capture (because it's async and the compositor
        // refuses capture when locked)
        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "lock"
        description: "Lock the current session"
        onPressed: lock.locked = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            lock.locked = true;
        }

        function bootLock(): void {
            root.bootLockActive = true;
            lock.locked = true;
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }
}
