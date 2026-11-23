pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.components.misc
import qs.services
import qs.utils

Singleton {
    id: root

    property list<NotifData> list: []
    readonly property list<NotifData> notClosed: list.filter(n => !n.closed)
    readonly property list<NotifData> popups: list.filter(n => n.popup)

    property bool loaded
    property bool scheduledDndActive: false
    readonly property bool effectiveDnd: PersistentState.doNotDisturb || scheduledDndActive || (NotifRules.dndWhenGaming && RuntimeState.gameMode)

    function _toMinutes(hhmm: string): int {
        const m = String(hhmm ?? "").match(/^(\d{1,2}):(\d{2})$/);
        if (!m)
            return -1;
        return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
    }

    function updateSchedule(): void {
        if (!NotifRules.dndScheduleEnabled) {
            scheduledDndActive = false;
            return;
        }
        const from = _toMinutes(NotifRules.dndScheduleFrom);
        const to = _toMinutes(NotifRules.dndScheduleTo);
        if (from < 0 || to < 0 || from === to) {
            scheduledDndActive = false;
            return;
        }
        const now = new Date();
        const cur = now.getHours() * 60 + now.getMinutes();
        scheduledDndActive = from < to ? (cur >= from && cur < to) : (cur >= from || cur < to);
    }

    // A click on a notification: the app's "default" action (the notification spec), else its
    // only action when actionOnClick is set, else the app that sent it to the front. Restored
    // from history (after a restart) its actions can't run any more (their sender is gone): the
    // update notification opens Settings > Updates instead, the others bring their app forward.
    function activate(n: var): void {
        const actions = n?.actions ?? [];
        const def = actions.find(a => a.identifier === "default") ?? (GlobalConfig.notifs.actionOnClick && actions.length === 1 ? actions[0] : null);
        if (def && typeof def.invoke === "function") {
            def.invoke();
            return;
        }
        if (n?.appName === "Updates") {
            Quickshell.execDetached(["caelestia", "shell", "nexus", "openPage", "updates", ""]);
            return;
        }
        focusSender(n);
    }

    // The window of the app that sent it (its desktop entry or name against the windows'
    // classes), brought to the front (restored if minimized)
    function focusSender(n: var): void {
        const keys = [n?.hints?.["desktop-entry"], n?.appName].filter(k => !!k).map(k => String(k).toLowerCase().replace(/\.desktop$/, ""));
        if (keys.length === 0)
            return;
        const matches = c => !!c && keys.some(k => c === k || c.endsWith("." + k) || k.endsWith("." + c));
        const t = Hyprland.toplevels.values.find(t => {
            const ipc = t.lastIpcObject ?? {};
            return matches(String(ipc.class ?? "").toLowerCase()) || matches(String(ipc.initialClass ?? "").toLowerCase());
        });
        if (t)
            TaskbarApps.hyprflow("activate", t);
    }

    function hasFullscreen(): bool {
        for (const monitor of Hypr.monitors.values) {
            if (monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1))
                return true;
        }
        return false;
    }

    function shouldShowPopup(notif: var): bool {
        if (ShellState.anySidebarOpen())
            return false;
        // The fullscreen rule first: do not disturb can only hide more than
        // without it (an urgent one it lets through still stays off a game)
        if (GlobalConfig.notifs.fullscreen === NotifsFullscreen.Off && hasFullscreen())
            return false;
        if (effectiveDnd)
            return NotifRules.dndAllowCritical && notif?.urgency === NotificationUrgency.Critical;
        return true;
    }

    // The per-app rules ready before the first notification
    Component.onCompleted: {
        NotifRules.ensureLoaded();
        updateSchedule();
    }

    Connections {
        function onDndScheduleEnabledChanged(): void {
            root.updateSchedule();
        }
        function onDndScheduleFromChanged(): void {
            root.updateSchedule();
        }
        function onDndScheduleToChanged(): void {
            root.updateSchedule();
        }

        target: NotifRules
    }

    Timer {
        interval: 30000
        repeat: true
        running: NotifRules.dndScheduleEnabled
        triggeredOnStart: true
        onTriggered: root.updateSchedule()
    }

    // The shell's own messages (Toaster.toast: "Copied", "Do not disturb enabled"...) are real
    // notifications: sent to this server, so they pop up, follow do not disturb and the rules,
    // and stay in the history like any other. Their icon goes along as a hint.
    property var seenToasts: []

    Connections {
        function onToastsChanged(): void {
            const list = Array.from(Toaster.toasts);
            for (const t of list) {
                if (root.seenToasts.includes(t))
                    continue;
                const urgency = t.type === Toast.Error ? "critical" : t.type === Toast.Success ? "low" : "normal";
                Quickshell.execDetached(["notify-send", "-a", "Caelestia", "-u", urgency, "-t", String(t.timeout), "-h", `string:x-caelestia-icon:${t.icon || "info"}`, t.title, t.message]);
                t.close();
            }
            root.seenToasts = list.filter(t => !t.closed);
        }

        target: Toaster
    }

    onListChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Connections {
        function onDoNotDisturbChanged(): void {
            if (!GlobalConfig.utilities.toasts.dndChanged)
                return;

            if (PersistentState.doNotDisturb)
                Toaster.toast(Tr.tr("Do not disturb enabled"), Tr.tr("Popup notifications are now disabled"), "do_not_disturb_on");
            else
                Toaster.toast(Tr.tr("Do not disturb disabled"), Tr.tr("Popup notifications are now enabled"), "do_not_disturb_off");
        }

        target: PersistentState
    }

    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify(root.notClosed.map(n => ({
                    time: n.time,
                    notificationId: n.notificationId,
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    appName: n.appName,
                    image: n.image,
                    expireTimeout: n.expireTimeout,
                    urgency: n.urgency,
                    resident: n.resident,
                    hasActionIcons: n.hasActionIcons,
                    actions: n.actions
                }))))
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            // Per-app settings: "off" drops it, "quiet" keeps it out of popups
            NotifRules.saw(notif.appName, notif.appIcon);
            const mode = NotifRules.mode(notif.appName);
            if (mode === "off")
                return; // untracked: Quickshell discards it

            notif.tracked = true;

            const comp = notifComp.createObject(root, {
                popup: mode !== "quiet" && root.shouldShowPopup(notif),
                notification: notif
            });
            if (comp.popup && NotifRules.sound && notif.urgency !== NotificationUrgency.Low)
                NotifRules.play("");
            root.list = [comp, ...root.list];
        }
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/notifs.json`
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (Array.isArray(data)) {
                    const loadedList = [];
                    for (const notif of data) {
                        const properties = Object.assign({}, notif);

                        // Backwards compatibility for old notifications
                        if (properties.notificationId === undefined && properties.id !== undefined)
                            properties.notificationId = properties.id;

                        delete properties.id;
                        loadedList.push(notifComp.createObject(root, properties));
                    }
                    // Notifications that came in before the stored ones finished loading stay
                    // (first load only: later loads replace the list)
                    const merged = root.loaded ? loadedList : [...root.list, ...loadedList];
                    merged.sort((a, b) => b.time - a.time);
                    root.list = merged;
                }
            } catch (e) {
                console.warn("Notifs: failed to parse stored notifications", e);
            }
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.loaded = true;
                Qt.callLater(() => setText("[]"));
            }
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clearNotifs"
        description: "Clear all notifications"
        onPressed: {
            for (const notif of root.list.slice())
                notif.close();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "toggleDnd"
        description: "Toggle do not disturb"
        onPressed: {
            PersistentState.doNotDisturb = !PersistentState.doNotDisturb;
        }
    }

    IpcHandler {
        function clear(): void {
            for (const notif of root.list.slice())
                notif.close();
        }

        function isDndEnabled(): bool {
            return PersistentState.doNotDisturb;
        }

        function toggleDnd(): void {
            PersistentState.doNotDisturb = !PersistentState.doNotDisturb;
        }

        function enableDnd(): void {
            PersistentState.doNotDisturb = true;
        }

        function disableDnd(): void {
            PersistentState.doNotDisturb = false;
        }

        target: "notifs"
    }

    Component {
        id: notifComp

        NotifData {}
    }
}
