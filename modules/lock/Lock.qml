pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import qs.components.misc

Scope {
    id: root

    property alias lock: lock
    readonly property string bootSentinel: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/caelestia-boot-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "default")
    readonly property bool startLocked: Quickshell.env("CAELESTIA_BOOT_LOCK") === "1" && !CUtils.fileExists(bootSentinel)
    property bool bootLockActive: startLocked
    property bool bootCursorRestored: false

    function revealBootCursor(): void {
        if (bootCursorRestored)
            return;
        bootCursorRestored = true;
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { invisible = false } })"]);
        // The boot splash (extras/boot-splash) has done its part: the lock screen covers it now
        Quickshell.execDetached(["sh", "-c", 'sleep 0.3; f="$XDG_RUNTIME_DIR/caelestia-boot-splash.pid"; [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; true']);
    }

    function runBootAutostart(): void {
        const sentinel = root.bootSentinel;
        Quickshell.execDetached(["sh", "-c", `
pkill -x gcr-prompter >/dev/null 2>&1 || true
SENT="$1"
[ -e "$SENT" ] && exit 0
touch "$SENT"
python3 - <<'PY'
import glob, os, re, subprocess
d = os.path.expanduser("~/.config/autostart")
for p in sorted(glob.glob(os.path.join(d, "*.desktop"))):
    try:
        txt = open(p, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    if re.search(r"^Hidden=true$", txt, re.M) or re.search(r"^X-GNOME-Autostart-enabled=false$", txt, re.M):
        continue
    m = re.search(r"^Exec=(.+)$", txt, re.M)
    if not m:
        continue
    cmd = re.sub(r"%[fFuUdDnNickvm]", "", m.group(1)).strip()
    if cmd:
        subprocess.Popen(["sh", "-c", cmd], start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY
`, "sh", sentinel]);
    }

    WlSessionLock {
        id: lock

        signal unlock

        locked: root.startLocked

        onLockedChanged: {
            if (!locked && root.bootLockActive) {
                root.bootLockActive = false;
                root.runBootAutostart();
            }
        }

        LockSurface {
            lock: lock
            pam: pam
            bootLock: root.bootLockActive
            onFirstFrameDrawn: root.revealBootCursor()
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
