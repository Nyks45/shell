pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // A local path as a file:// URL (each part encoded: names with spaces, # or ?)
    function url(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
}
