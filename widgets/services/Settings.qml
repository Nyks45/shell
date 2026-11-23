pragma Singleton

import QtQuick
import Quickshell
import qs.utils
import Quickshell.Io

// The desktop widgets' own settings (~/.config/caelestia/widgets/settings.json): the widgets
// themselves and the now-playing widget's spin. Everything else follows the shell's settings.
Singleton {
    id: root

    readonly property string directory: Paths.config + "/widgets"
    // Where the settings were kept before (moved to `directory` on the first start)
    readonly property string oldDirectory: Paths.config + "/nebula"
    readonly property alias nowPlaying: adapter.nowPlaying
    readonly property alias widgets: adapter.widgets
    property bool ready: false

    component WidgetsGroup: JsonObject {
        property string items: ""
        property string presets: "[]"
        property string preset: ""
        property bool grid: false
        property string toolbarEdge: "bottom"
    }

    component NowPlayingGroup: JsonObject {
        property bool spin: true
        property int spinSeconds: 60
    }

    // The folder first, then the file: read (and, on a first run, written) only once the folder
    // exists, else the first run's write fails and nothing is saved.
    property bool dirReady: false

    // An existing folder from before the rename is moved over first (only when the new one
    // isn't there yet, so nothing is overwritten)
    Process {
        running: true
        command: ["sh", "-c", 'if [ -d "$1" ] && [ ! -e "$2" ]; then mv "$1" "$2"; fi; mkdir -p "$2"', "sh", root.oldDirectory, root.directory]
        onExited: root.dirReady = true
    }

    FileView {
        id: file
        path: root.dirReady ? root.directory + "/settings.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // A missing file on the first run is expected (written just below): no warning for it
        printErrors: false
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) return;
            root.ready = true;
            writeAdapter();
        }
        onSaved: if (!loaded) reload()

        JsonAdapter {
            id: adapter

            property NowPlayingGroup nowPlaying: NowPlayingGroup {}
            property WidgetsGroup widgets: WidgetsGroup {}
        }
    }
}
