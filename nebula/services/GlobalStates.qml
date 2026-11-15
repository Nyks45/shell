pragma Singleton

import QtQuick
import Quickshell
import qs.modules.nexus
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property bool launcherOpen: false
    property bool galaxyOpen: false
    property bool powerMenuOpen: false
    property bool quickSettingsOpen: false
    property bool calendarOpen: false
    property bool trayOpen: false
    property bool systemOpen: false
    property bool mediaExpanded: false
    property string dockPreview: ""
    property string dockContext: ""
    property bool settingsOpen: false
    property bool settingsFromQuick: false
    property string settingsPage: ""
    property string settingsTab: ""
    property string screen: ""
    property bool capturing: false
    property string pickFor: ""
    readonly property bool popupOpen: powerMenuOpen || quickSettingsOpen || calendarOpen || trayOpen || systemOpen || mediaExpanded || dockPreview !== "" || dockContext !== ""

    function isOn(screenName) {
        return screen === screenName;
    }

    function focusedScreen() {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    function toggleLauncher(screenName = focusedScreen()) {
        if (launcherOpen && screen === screenName) {
            launcherOpen = false;
        } else {
            closeAll();
            screen = screenName;
            launcherOpen = true;
        }
    }

    function toggleGalaxy(screenName = focusedScreen()) {
        if (galaxyOpen && screen === screenName) {
            galaxyOpen = false;
        } else {
            closeAll();
            screen = screenName;
            galaxyOpen = true;
        }
    }

    function togglePowerMenu(screenName = focusedScreen()) {
        if (powerMenuOpen && screen === screenName) {
            powerMenuOpen = false;
        } else {
            closeAll();
            screen = screenName;
            powerMenuOpen = true;
        }
    }

    function toggleQuickSettings(screenName = focusedScreen()) {
        if (quickSettingsOpen && screen === screenName) {
            quickSettingsOpen = false;
        } else {
            closeAll();
            screen = screenName;
            quickSettingsOpen = true;
        }
    }

    function toggleTray(screenName = focusedScreen()) {
        if (trayOpen && screen === screenName) {
            trayOpen = false;
        } else {
            closeAll();
            screen = screenName;
            trayOpen = true;
        }
    }

    function openDockPreview(key, screenName = focusedScreen()) {
        if (dockPreview === key && screen === screenName) return;
        closeAll();
        screen = screenName;
        dockPreview = key;
    }

    function toggleDockContext(key, screenName = focusedScreen()) {
        if (dockContext === key && screen === screenName) {
            dockContext = "";
        } else {
            closeAll();
            screen = screenName;
            dockContext = key;
        }
    }

    function toggleCalendar(screenName = focusedScreen()) {
        if (calendarOpen && screen === screenName) {
            calendarOpen = false;
        } else {
            closeAll();
            screen = screenName;
            calendarOpen = true;
        }
    }

    function toggleSystem(screenName = focusedScreen()) {
        if (systemOpen && screen === screenName) {
            systemOpen = false;
        } else {
            closeAll();
            screen = screenName;
            systemOpen = true;
        }
    }

    function toggleMedia(screenName = focusedScreen()) {
        if (mediaExpanded && screen === screenName) {
            mediaExpanded = false;
        } else {
            closeAll();
            screen = screenName;
            mediaExpanded = true;
        }
    }

    function toggleSettings(screenName = focusedScreen(), fromQuick = false) {
        if (settingsOpen) {
            settingsOpen = false;
        } else {
            closeAll();
            screen = screenName;
            settingsFromQuick = fromQuick;
            settingsOpen = true;
        }
    }

    function openSettings(page, tab = "", fromQuick = false) {
        // In the shell's settings app: Nebula's desktop pages under Style, its other pages at the
        // shell's page for the same thing (Nebula's own settings window is part of its bar)
        const shellPages = { appearance: "wallpaper", windows: "windows", bar: "panels", connections: "network", system: "display", apps: "apps", notifications: "notifications", recorder: "panels", about: "about" };
        if (page === "desktop" || shellPages[page]) {
            closeAll();
            if (page === "desktop")
                SettingsNav.open(tab);
            else
                WindowFactory.createAt(shellPages[page], []);
            return;
        }
        settingsPage = page;
        settingsTab = tab;
        if (!settingsOpen) toggleSettings(focusedScreen(), fromQuick);
    }

    function closePopups(keepMedia = false) {
        if (!keepMedia) mediaExpanded = false;
        powerMenuOpen = false;
        quickSettingsOpen = false;
        calendarOpen = false;
        trayOpen = false;
        systemOpen = false;
        dockPreview = "";
        dockContext = "";
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!root.popupOpen || root.capturing) return;
            if (event.name === "workspacev2" || event.name === "focusedmonv2" || (event.name === "activewindowv2" && event.data !== ""))
                root.closePopups(event.name === "activewindowv2");
        }
    }

    function closeAll() {
        launcherOpen = false;
        galaxyOpen = false;
        powerMenuOpen = false;
        quickSettingsOpen = false;
        calendarOpen = false;
        trayOpen = false;
        systemOpen = false;
        mediaExpanded = false;
        dockPreview = "";
        dockContext = "";
        settingsOpen = false;
    }

    IpcHandler {
        target: "nebulaMedia"

        function toggle(): void { if (Media.active) root.toggleMedia(); }
    }

    IpcHandler {
        target: "nebulaMissed"

        function toggle(): void { root.toggleGalaxy(); }
        function clear(): void { Notifications.clearMissed(); }
    }

    IpcHandler {
        target: "nebulaTray"

        function toggle(): void { root.toggleTray(); }
    }

    IpcHandler {
        target: "nebulaCalendar"

        function toggle(): void { root.toggleCalendar(); }
    }

    IpcHandler {
        target: "nebulaSystem"

        function toggle(): void { root.toggleSystem(); }
    }

    IpcHandler {
        target: "nebulaQuicksettings"

        function toggle(): void { root.toggleQuickSettings(); }
    }

    IpcHandler {
        target: "nebulaSettings"

        function toggle(): void { root.toggleSettings(); }
        function open(page: string, tab: string): void { root.openSettings(page, tab); }
    }
}
