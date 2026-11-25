pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.modules.lock

Scope {
    id: root

    required property Lock lock
    readonly property bool needsAudioCheck: GlobalConfig.general.idle.inhibitWhenAudio || GlobalConfig.general.idle.timeouts.values.some(t => t.inhibitWhenAudio)
    readonly property bool hasPlayer: needsAudioCheck && Players.list.some(p => p.isPlaying)
    readonly property bool isCharging: !UPower.onBattery
    readonly property bool enabled: {
        if (GlobalConfig.general.idle.inhibitWhenAudio && hasPlayer)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenCharging && isCharging)
            return false;
        return true;
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (typeof action === "string")
            Hypr.dispatch(Hypr.usingLua && ["dpms off", "dpms on"].includes(action) ? `hl.dsp.dpms({ action = "${action === "dpms off" ? "disable" : "enable"}" })` : action);
        else if (!SessionManager.exec(action))
            Quickshell.execDetached(action);
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    // Create the notifier with the saved timeout so it does not have to replace a live binding.
    Variants {
        model: root.enabled && LiveWallpaper.setting("screensaverEnabled", false) && !root.lock.lock.locked
            ? [LiveWallpaper.setting("screensaverTimeout", 600)] : []

        IdleMonitor {
            required property real modelData

            timeout: modelData
            respectInhibitors: true
            onIsIdleChanged: LiveWallpaper.screensaverActive = isIdle
            Component.onDestruction: LiveWallpaper.screensaverActive = false
        }
    }

    Process {
        id: saverCommand

        readonly property string wanted: LiveWallpaper.screensaverActive ? JSON.stringify([
            Object.entries(LiveWallpaper.screensaverScreens).map(([output, assignment]) =>
                [output, LiveWallpaper.wallpaperPath(assignment)]), LiveWallpaper.setting("screensaverSound", false)
        ]) : ""
        property string requested
        environment: ({ LIVE_WALLPAPER_RULE_SELECTION: LiveWallpaper.ruleSelection ? JSON.stringify(LiveWallpaper.ruleSelection) : "" })

        function reconcile(): void {
            if (running || wanted === requested)
                return;
            requested = wanted;
            command = [LiveWallpaper.scriptBin, wanted ? "screensaver-start" : "screensaver-stop"];
            running = true;
        }

        onWantedChanged: reconcile()
        onExited: reconcile()
        Component.onCompleted: reconcile()
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts.values

        IdleMonitor {
            required property var modelData

            enabled: {
                if (!root.enabled || !(modelData.enabled ?? true))
                    return false;
                if (modelData.inhibitWhenAudio && root.hasPlayer)
                    return false;
                if (modelData.inhibitWhenCharging && root.isCharging)
                    return false;
                return true;
            }
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
