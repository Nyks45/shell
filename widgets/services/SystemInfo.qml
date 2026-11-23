pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Whether there's a profile picture (the shell's face file): the terminal widget shows it
Singleton {
    id: root

    property bool hasAvatar: false

    Process {
        running: true
        command: ["test", "-f", Paths.face]
        onExited: code => root.hasAvatar = code === 0
    }
}
