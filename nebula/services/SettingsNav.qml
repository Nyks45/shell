pragma Singleton

import QtQuick
import Quickshell
import qs.modules.nexus

// Where Nebula's settings open: in the shell's settings app (Wallpaper & style > Nebula), at one of
// Nebula's own pages. `sub` is Nebula's sub-page key: "" (desktop widgets), "widget:<id>",
// "newwidget", "images".
Singleton {
    id: root

    property string sub: ""

    function open(sub: string): void {
        root.sub = sub ?? "";
        WindowFactory.createAt("wallpaper", [9, 10]); // Wallpaper & style > Nebula > its pages
    }
}
