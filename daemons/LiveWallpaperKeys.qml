import QtQuick
import Quickshell
import Quickshell.Io
import qs.components.misc
import qs.services

// Live wallpaper controls outside the settings app (what the Linux Wallpaper
// Engine GUI's tray menu did): `caelestia shell liveWallpaper random|pause|stop`
// and global shortcuts to bind keys to.
Scope {
    IpcHandler {
        function random(): void {
            LiveWallpaper.random();
        }

        function pause(): void {
            LiveWallpaper.togglePause();
        }

        function stop(): void {
            LiveWallpaper.useStatic();
        }

        target: "liveWallpaper"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "liveWallpaperRandom"
        description: "Another live wallpaper, at random"
        onPressed: LiveWallpaper.random()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "liveWallpaperPause"
        description: "Pause or resume the live wallpaper"
        onPressed: LiveWallpaper.togglePause()
    }
}
