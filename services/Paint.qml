pragma Singleton

import QtQuick
import Quickshell

// Paint is its own app (paint.qml next to shell.qml, started by assets/caelestia-paint):
// a screenshot's "Edit", the launcher and `caelestia shell paint open|file` hand it pictures.
Singleton {
    id: root

    readonly property string launcher: `${Quickshell.shellDir}/assets/caelestia-paint`

    // `path`: an image file, or "" for a new picture
    function open(path: string): void {
        Quickshell.execDetached(["env", `CAELESTIA_PAINT_QML=${Quickshell.shellDir}/paint.qml`, launcher, ...(path ? [path] : [])]);
    }
}
