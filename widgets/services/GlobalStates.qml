pragma Singleton

import QtQuick
import Quickshell
import qs.modules.nexus
import Quickshell.Hyprland

// What the desktop widgets share: the screen they were last used on, and opening their
// settings in the shell's settings app.
Singleton {
    id: root

    property string screen: ""

    function focusedScreen() {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    // The widgets' pages under Wallpaper & style > Desktop; anything else at the shell's own page
    function openSettings(page, tab = "") {
        const shellPages = { appearance: "wallpaper", windows: "windows", bar: "panels", connections: "network", system: "display", apps: "apps", notifications: "notifications", about: "about" };
        if (page === "desktop")
            SettingsNav.open(tab);
        else
            WindowFactory.createAt(shellPages[page] ?? "wallpaper", []);
    }
}
