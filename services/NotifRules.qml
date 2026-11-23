pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Per-app notification settings (Settings > Notifications > Apps), kept in
// notif-apps.json: { rules: { appName: "all" | "quiet" | "off" }, seen: { appName: icon } }.
// "quiet": into the notification list, no popup; "off": dropped.
Singleton {
    id: root

    property var rules: ({})
    property var seen: ({})
    property bool loaded
    // A sound when a notification pops up (not for quiet/low-urgency ones)
    property bool sound
    property string soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga"
    // Automatic Do not disturb rules & critical override
    property bool dndScheduleEnabled: false
    property string dndScheduleFrom: "22:00"
    property string dndScheduleTo: "07:00"
    property bool dndWhenGaming: false
    // Off unless chosen: do not disturb used to hold back every popup
    property bool dndAllowCritical: false

    function setSound(on: bool, file: string): void {
        sound = on;
        if (file)
            soundFile = file;
        save();
    }

    function setDndRules(changes: var): void {
        ensureLoaded();
        if ("dndScheduleEnabled" in changes)
            dndScheduleEnabled = !!changes.dndScheduleEnabled;
        if ("dndScheduleFrom" in changes && changes.dndScheduleFrom)
            dndScheduleFrom = String(changes.dndScheduleFrom);
        if ("dndScheduleTo" in changes && changes.dndScheduleTo)
            dndScheduleTo = String(changes.dndScheduleTo);
        if ("dndWhenGaming" in changes)
            dndWhenGaming = !!changes.dndWhenGaming;
        if ("dndAllowCritical" in changes)
            dndAllowCritical = !!changes.dndAllowCritical;
        save();
    }

    function play(file: string): void {
        Quickshell.execDetached(["pw-play", file || soundFile]);
    }

    function mode(app: string): string {
        ensureLoaded();
        return rules[app] ?? "all";
    }

    // The file loads asynchronously; a notification can come before that
    // (it may be what created this service): read it now
    function ensureLoaded(): void {
        if (loaded)
            return;
        parse(file.text());
        loaded = true;
    }

    function parse(text: string): void {
        try {
            const data = JSON.parse(text);
            rules = data.rules ?? {};
            seen = data.seen ?? {};
            sound = !!data.sound;
            if (data.soundFile)
                soundFile = data.soundFile;
            dndScheduleEnabled = !!data.dndScheduleEnabled;
            if (data.dndScheduleFrom)
                dndScheduleFrom = String(data.dndScheduleFrom);
            if (data.dndScheduleTo)
                dndScheduleTo = String(data.dndScheduleTo);
            dndWhenGaming = !!data.dndWhenGaming;
            if ("dndAllowCritical" in data)
                dndAllowCritical = !!data.dndAllowCritical;
        } catch (e) {}
    }

    function setMode(app: string, value: string): void {
        const next = Object.assign({}, rules);
        if (value === "all")
            delete next[app];
        else
            next[app] = value;
        rules = next;
        save();
    }

    // Remember apps that sent something, so the settings can list them
    function saw(app: string, icon: string): void {
        if (!app || (app in seen && (seen[app] || !icon)))
            return;
        const next = Object.assign({}, seen);
        next[app] = icon ?? "";
        seen = next;
        saveTimer.restart();
    }

    function forget(app: string): void {
        const s = Object.assign({}, seen);
        delete s[app];
        seen = s;
        const r = Object.assign({}, rules);
        delete r[app];
        rules = r;
        save();
    }

    function save(): void {
        if (loaded)
            file.setText(JSON.stringify({
                rules,
                seen,
                sound,
                soundFile,
                dndScheduleEnabled,
                dndScheduleFrom,
                dndScheduleTo,
                dndWhenGaming,
                dndAllowCritical
            }, null, 4) + "\n");
    }

    Timer {
        id: saveTimer

        interval: 2000
        onTriggered: root.save()
    }

    FileView {
        id: file

        path: `${Paths.config}/notif-apps.json`
        printErrors: false
        // text() waits for the file (ensureLoaded reads it before it's loaded)
        blockAllReads: true
        // Edited by hand (or another instance): read it again
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.parse(text());
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
