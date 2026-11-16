pragma Singleton

import QtQuick
import Quickshell

// Paint: the shell's drawing app (modules/paint/PaintWindow.qml). Opens on a screenshot (a
// click on the screenshot notification), on an image, or on a blank page (the app launcher's
// Paint, `caelestia shell paint open`; IPC in daemons/Shortcuts.qml). Each open is its own window.
Singleton {
    id: root

    // `path`: an image file, or "" for a blank page
    function open(path: string): void {
        const comp = Qt.createComponent(Qt.resolvedUrl("../modules/paint/PaintWindow.qml"));
        if (comp.status === Component.Error) {
            console.warn("Paint:", comp.errorString());
            return;
        }
        comp.createObject(root, {
            source: path ?? ""
        });
    }
}
