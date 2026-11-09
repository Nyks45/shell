pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

// Apps and packages (Settings › Apps): installing, removing and updating
// system packages (pacman, through the settings' root helper), AUR packages
// (paru, its pacman step through the shell's password prompt) and Flatpak
// apps (flatpak, which asks polkit itself). Reading goes through
// caelestia-packages (JSON). Also checks for updates every few hours and
// notifies (GlobalConfig.services.updateCheckHours / updateNotify), and says
// when a restart is needed after a kernel or driver update.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-packages`

    // Waiting updates: [{ name, from, to, appId? }]
    property var repo: []
    property var aur: []
    property var flatpak: []
    // Why a restart is needed: ["kernel", "nvidia"]
    property var restart: []
    property var held: []
    property date checkedAt
    property bool checking
    readonly property int total: repo.length + aur.length + flatpak.length

    // Installed packages ({ packages, totalPackages }), loaded on demand
    property var installed: null
    property bool loadingInstalled

    // Packages being installed/removed/updated: "source:name" -> "install"|"remove"|"update"
    property var busy: ({})
    readonly property string updateWhat: qsTr("Install the updates")
    property string updateStep
    readonly property bool updating: updateStep !== ""

    // After any change (lists reload; open pages re-read their package)
    signal changed

    // The launcher entry people know a package by: one named like the
    // package, else the first shown one (nautilus also has "Run Software")
    function entryOf(item: var): DesktopEntry {
        const ids = item?.apps ?? (item?.appId ? [item.appId] : []);
        const entries = ids.map(id => DesktopEntries.byId(id)).filter(e => e);
        const n = (item?.name ?? "").toLowerCase().replace(/-(bin|git|nightly)$/, "");
        return entries.find(e => e.id.toLowerCase().includes(n)) ?? entries.find(e => !e.noDisplay) ?? entries[0] ?? null;
    }

    function displayName(item: var): string {
        return entryOf(item)?.name || item?.name || "";
    }

    function key(item: var): string {
        return `${item.source}:${item.appId || item.name}`;
    }

    function setBusy(item: var, what: string): void {
        const b = Object.assign({}, busy);
        if (what)
            b[key(item)] = what;
        else
            delete b[key(item)];
        busy = b;
    }

    // quiet: asked from Settings (no notification: it's on screen already)
    function check(quiet: bool): void {
        if (checking)
            return;
        quietCheck = !!quiet;
        checking = true;
        updatesProc.running = true;
    }

    property bool quietCheck

    function loadInstalled(): void {
        loadingInstalled = true;
        installedProc.running = true;
    }

    function afterChange(): void {
        loadInstalled();
        check(true);
        changed();
    }

    function install(item: var, done: var): void {
        const name = item.appId || item.name;
        const what = qsTr("Install %1").arg(item.name);
        setBusy(item, "install");
        const end = (ok, out, cancelled) => {
            setBusy(item, "");
            afterChange();
            if (typeof done === "function")
                done(ok, out, cancelled);
        };
        if (item.source === "repo")
            Admin.run("install", [name], what, end);
        else if (item.source === "aur")
            Admin.exec(["paru", "-S", "--noconfirm", "--skipreview", "--sudo", "pkexec", "--", name], what, end);
        else
            Admin.exec(["flatpak", "install", "--system", "-y", "--noninteractive", item.remote || "flathub", name], what, end);
    }

    function remove(item: var, keepDeps: bool, done: var): void {
        const name = item.appId || item.name;
        const what = qsTr("Remove %1").arg(item.name);
        setBusy(item, "remove");
        const end = (ok, out, cancelled) => {
            setBusy(item, "");
            afterChange();
            if (typeof done === "function")
                done(ok, out, cancelled);
        };
        if (item.source === "flatpak")
            Admin.exec(["flatpak", "uninstall", "-y", "--noninteractive", name], what, end);
        else
            Admin.run("remove", [...(keepDeps ? ["--keep-deps"] : []), name], what, end);
    }

    // The chosen updates: system packages all but `skipRepo` (pacman can only
    // update them together), then the chosen AUR packages, then the chosen
    // Flatpak apps (by app id)
    function update(skipRepo: list<string>, aurNames: list<string>, flatpakIds: list<string>, done: var): void {
        const finish = ok => {
            updateStep = "";
            afterChange();
            if (restart.length === 0)
                restartCheck.running = true;
            if (typeof done === "function")
                done(ok);
        };
        const flatpakStep = () => {
            if (flatpakIds.length === 0)
                return finish(true);
            updateStep = "flatpak";
            Admin.exec(["flatpak", "update", "--system", "-y", "--noninteractive", ...flatpakIds], updateWhat, ok => finish(ok));
        };
        const aurStep = () => {
            if (aurNames.length === 0)
                return flatpakStep();
            updateStep = "aur";
            Admin.exec(["paru", "-S", "--noconfirm", "--skipreview", "--sudo", "pkexec", "--", ...aurNames], updateWhat, ok => ok ? flatpakStep() : finish(false));
        };
        if (repo.length === 0 || skipRepo.length >= repo.length)
            return aurStep();
        updateStep = "repo";
        Admin.run("upgrade", skipRepo.length > 0 ? ["--ignore", ...skipRepo] : [], updateWhat, ok => ok ? aurStep() : finish(false));
    }

    function hold(name: string, on: bool): void {
        Admin.run(on ? "hold" : "unhold", [name], on ? qsTr("Keep %1 at its version").arg(name) : qsTr("Update %1 again").arg(name), () => afterChange());
    }

    function notify(title: string, body: string): void {
        if (!GlobalConfig.services.updateNotify)
            return;
        notifyProc.command = ["notify-send", "-a", "Updates", "-i", "system-software-update", "--action=open=Open", title, body];
        notifyProc.running = true;
    }

    // Notified for this set of updates already (only a new one notifies again)
    property string notifiedKey

    Process {
        id: updatesProc

        command: [root.helper, "updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.repo = d.repo ?? [];
                    root.aur = d.aur ?? [];
                    root.flatpak = d.flatpak ?? [];
                    root.held = d.held ?? [];
                    root.restart = d.restart ?? [];
                } catch (e) {}
                root.checkedAt = new Date();
                root.checking = false;
                const k = [...root.repo, ...root.aur, ...root.flatpak].map(u => `${u.name}=${u.to}`).sort().join(" ");
                if (root.total > 0 && k !== root.notifiedKey && !root.updating) {
                    root.notifiedKey = k;
                    if (!root.quietCheck)
                        root.notify(root.total === 1 ? qsTr("1 update available") : qsTr("%1 updates available").arg(root.total), [root.repo.length > 0 ? qsTr("%1 system").arg(root.repo.length) : "", root.aur.length > 0 ? qsTr("%1 AUR").arg(root.aur.length) : "", root.flatpak.length > 0 ? qsTr("%1 Flatpak").arg(root.flatpak.length) : ""].filter(s => s).join(", "));
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.checking = false;
        }
    }

    Process {
        id: restartCheck

        command: [root.helper, "restart"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.restart = JSON.parse(text).reasons ?? [];
                } catch (e) {}
                if (root.restart.length > 0)
                    root.notify(qsTr("Restart to finish updating"), root.restart.includes("kernel") ? qsTr("A new kernel was installed.") : qsTr("The graphics driver was updated."));
            }
        }
    }

    Process {
        id: installedProc

        command: [root.helper, "installed"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.installed = JSON.parse(text);
                } catch (e) {}
                root.loadingInstalled = false;
            }
        }
    }

    // notify-send waits for the action: "open" opens Settings › Apps › Updates
    Process {
        id: notifyProc

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "open")
                Quickshell.execDetached(["caelestia", "shell", "nexus", "openPage", "updates", ""])
        }
    }

    // A first check a while after login, then every few hours
    Timer {
        running: GlobalConfig.services.updateCheckHours > 0
        interval: 3 * 60 * 1000
        onTriggered: root.check()
    }

    Timer {
        running: GlobalConfig.services.updateCheckHours > 0
        repeat: true
        interval: Math.max(1, GlobalConfig.services.updateCheckHours) * 3600 * 1000
        onTriggered: root.check()
    }
}
