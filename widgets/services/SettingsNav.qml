pragma Singleton

import QtQuick
import Quickshell
import qs.modules.nexus

// Where the desktop widgets' settings open: in the shell's settings app (Wallpaper & style >
// Widgets and layouts), at one of
// The desktop widgets' own pages. `sub` is their sub-page key: "" (desktop widgets), "widget:<id>",
// "newwidget", "images".
Singleton {
    id: root

    property string sub: ""

    function open(sub: string): void {
        root.sub = sub ?? "";
        WindowFactory.createAt("wallpaper", [9]); // Wallpaper & style > Widgets and layouts
    }
}
