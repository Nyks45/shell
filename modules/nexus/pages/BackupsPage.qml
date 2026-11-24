pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// System snapshots (snapper, btrfs): the list, making one, deleting, and
// the automatic ones. Root snapshots are in the boot menu (rEFInd), so the
// PC can be started from one if an update breaks it. snapper only lets users
// listed in its config (ALLOW_USERS) do this without sudo; the page offers to
// add this account once, and can also set up snapshots for a btrfs /home.
PageBase {
    id: root

    property string config: "root"
    // [{ config, subvolume }]
    property var configs: []
    property bool homeIsBtrfs
    property bool allowed
    property bool checked
    property bool hasSnapper
    // { number, type, date, description, cleanup, userdata }
    property var snapshots: []
    property var settings: ({})
    property string newDescription
    property string snapFilter: "all" // "all", "manual", "hourly"
    property string cleanupAgePreset: "7d" // "24h", "3d", "7d", "14d", "30d", "custom"
    property int cleanupCustomDays: 14
    property string cleanupScope: "all" // "all", "hourly", "manual"
    property string pendingSnapperToast: ""
    property int limitHourly: 5
    property int limitDaily: 7
    property int limitWeekly: 4
    property bool limitsDirty: false
    property bool bootedSnapshot: false
    // Why snapper's rollback can't work here ("" when it can): this system
    // starts from the subvolume its boot entry names (rootflags=subvol=/@),
    // so changing the btrfs default subvolume has no effect
    property string rollbackBlocker: ""
    property var homeBackup: ({
            dest: "",
            excludeCaches: true,
            daily: false,
            lastRun: 0,
            lastStatus: ""
        })
    property bool homeBackupSameDev: false
    property bool homeBackingUp: false
    property string homeBackupProgress: ""
    property bool homeDailyActive: false
    property bool timerRefreshed: false
    readonly property string homeDir: (Quickshell.env("HOME") || "").replace(/\/$/, "")
    readonly property bool homeBackupInHome: !!homeBackup.dest && (homeBackup.dest.replace(/\/$/, "") + "/").startsWith(homeDir + "/")
    readonly property string homeBackupConfig: `${Paths.config}/home-backup.json`
    // The copy itself, for "Back up now" and the daily timer alike (the timer
    // runs it from a file): reads home-backup.json when it runs, so the timer
    // always uses the destination set now; checks the drive is there; leaves a
    // backup folder inside home out of the copy; writes lastRun/lastStatus back
    readonly property string backupScript: `import json, os, signal, subprocess, sys, time
cfg_path = sys.argv[1]
def load():
    try:
        with open(cfg_path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}
def save(changes):
    d = load()
    d.update(changes)
    tmp = cfg_path + ".tmp"
    with open(tmp, "w") as f:
        f.write(json.dumps(d, indent=4) + chr(10))
    os.replace(tmp, cfg_path)
def fail(note, code):
    save({"lastStatus": "error", "lastNote": note})
    print(note, file=sys.stderr, flush=True)
    sys.exit(code)
def mount_of(p):
    while p and p != "/" and not os.path.exists(p):
        p = os.path.dirname(p)
    r = subprocess.run(["findmnt", "-n", "-o", "TARGET,FSTYPE", "--target", p or "/"], capture_output=True, text=True)
    parts = r.stdout.split()
    return (parts[0], parts[1]) if len(parts) >= 2 else ("", "")
d = load()
dest = (d.get("dest") or "").rstrip("/")
if not dest:
    fail("No backup destination is set", 2)
mnt, fstype = mount_of(dest)
saved = d.get("destMount") or ""
# The drive it was chosen on must be there: otherwise the folder would be
# made on the system disk and the whole home folder copied onto it
if saved and mnt != saved:
    fail("The backup drive isn't connected (%s isn't mounted)" % saved, 3)
if not saved and mnt in ("/", "/home") and dest.startswith(("/mnt/", "/media/", "/run/media/")):
    fail("The backup drive isn't connected (%s is on the system disk)" % dest, 3)
home = os.path.expanduser("~").rstrip("/")
target = dest + "/home-backup"
os.makedirs(target, exist_ok=True)
# NTFS/exFAT/FAT keep no Unix owners, ACLs or extended attributes: copying
# those fails every run (rsync exit 23); times are 2 s exact on FAT
if fstype in ("ntfs", "ntfs3", "fuseblk", "exfat", "vfat", "msdos"):
    args = ["rsync", "-rlt", "--modify-window=2"]
else:
    args = ["rsync", "-aHAX"]
args += ["--delete", "--info=progress2", "--no-inc-recursive"]
if d.get("excludeCaches", True):
    for ex in (".cache", ".local/share/Steam/steamapps", ".local/share/Trash", "node_modules"):
        args += ["--exclude", ex]
# A backup folder inside the home folder is left out of it (else each run
# copies the last backup into the new one)
if target == home or target.startswith(home + "/"):
    args += ["--exclude", "/" + os.path.relpath(target, home)]
args += [home + "/", target + "/"]
proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
cancelled = False
def stop(*_):
    global cancelled
    cancelled = True
    proc.terminate()
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
# rsync redraws its progress line with a carriage return: one line each for the page
last_msg = ""
buf = b""
while True:
    chunk = proc.stdout.read1(4096)
    if not chunk:
        break
    buf += chunk.replace(bytes([13]), bytes([10]))
    *lines, buf = buf.split(bytes([10]))
    for raw in lines:
        line = raw.decode(errors="replace").strip()
        if not line:
            continue
        print(line, flush=True)
        if "%" not in line:
            last_msg = line
code = proc.wait()
if cancelled:
    fail("Cancelled", 130)
if code in (0, 24):
    # 24: files that went away while copying (normal on a home in use)
    save({"lastRun": int(time.time()), "lastStatus": "ok", "lastNote": "vanished" if code == 24 else ""})
    sys.exit(0)
fail(last_msg or "rsync exited with code %d" % code, code)
`

    readonly property real cleanupAgeMs: {
        if (cleanupAgePreset === "24h")
            return 86400000;
        if (cleanupAgePreset === "3d")
            return 3 * 86400000;
        if (cleanupAgePreset === "7d")
            return 7 * 86400000;
        if (cleanupAgePreset === "14d")
            return 14 * 86400000;
        if (cleanupAgePreset === "30d")
            return 30 * 86400000;
        return Math.max(1, cleanupCustomDays) * 86400000;
    }

    readonly property string cleanupAgeLabel: {
        if (cleanupAgePreset === "24h")
            return Tr.tr("24 hours");
        if (cleanupAgePreset === "3d")
            return Tr.trN("%n day", "%n days", 3);
        if (cleanupAgePreset === "7d")
            return Tr.trN("%n day", "%n days", 7);
        if (cleanupAgePreset === "14d")
            return Tr.trN("%n day", "%n days", 14);
        if (cleanupAgePreset === "30d")
            return Tr.trN("%n day", "%n days", 30);
        const days = Math.max(1, cleanupCustomDays);
        return Tr.trN("%n day", "%n days", days);
    }

    readonly property var cleanupCandidates: {
        const list = snapshots ?? [];
        if (list.length === 0)
            return [];
        let newestNum = -1;
        for (const s of list) {
            const n = Number(s.number);
            if (n > newestNum)
                newestNum = n;
        }
        const cutoffMs = Date.now() - cleanupAgeMs;
        return list.filter(s => {
            const n = Number(s.number);
            if (!n || n === 0 || s.active === true || s["default"] === true || n === newestNum)
                return false;
            if (cleanupScope === "hourly" && s.cleanup !== "timeline")
                return false;
            if (cleanupScope === "manual" && s.cleanup === "timeline")
                return false;
            const ts = parseSnapDateMs(s.date);
            return !isNaN(ts) && ts < cutoffMs;
        });
    }

    readonly property var filteredSnapshots: {
        if (snapFilter === "hourly")
            return snapshots.filter(s => s.cleanup === "timeline");
        if (snapFilter === "manual")
            return snapshots.filter(s => s.cleanup !== "timeline");
        return snapshots;
    }

    function parseSnapDateMs(dateStr: string): real {
        const m = String(dateStr ?? "").trim().match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/);
        if (!m)
            return NaN;
        return new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10), parseInt(m[4], 10), parseInt(m[5], 10), parseInt(m[6] ?? "0", 10)).getTime();
    }

    function snapDisplayTitle(snap: var): string {
        const desc = (snap.description ?? "").trim();
        if (desc) {
            if (snap.type === "pre")
                return Tr.tr("Before %1").arg(desc.replace(/^Before\s+/i, ""));
            if (snap.type === "post")
                return Tr.tr("After %1").arg(desc.replace(/^After\s+/i, ""));
            return desc;
        }
        return snap.cleanup === "timeline" ? Tr.tr("Automatic") : Tr.tr("Snapshot #%1").arg(snap.number);
    }

    function refresh(): void {
        listProc.running = false;
        listProc.running = true;
        configProc.running = false;
        configProc.running = true;
        configsProc.running = false;
        configsProc.running = true;
    }

    function snapper(args: list<string>): void {
        snapperProc.command = ["snapper", "-c", config, ...args];
        snapperProc.running = true;
    }

    function saveHomeBackup(changes: var): void {
        const next = Object.assign({}, homeBackup, changes);
        homeBackup = next;
        homeBackupFile.setText(JSON.stringify(next, null, 4) + "\n");
        if ("dest" in changes)
            homeBackupDevProc.running = true;
    }

    function runHomeBackupNow(): void {
        if (!homeBackup.dest || homeBackingUp)
            return;
        homeBackupProgress = Tr.tr("Starting backup…");
        homeBackingUp = true;
        rsyncProc.command = ["python3", "-I", "-c", backupScript, homeBackupConfig];
        rsyncProc.running = true;
    }

    function cancelHomeBackup(): void {
        if (homeBackingUp)
            rsyncProc.running = false;
    }

    // The daily timer on (writes the script and units) or off (removes them).
    // quiet: no message (refreshing old units when the page opens)
    function applyHomeDailyTimer(enabled: bool, quiet: bool): void {
        const on = enabled && !!homeBackup.dest;
        timerSetupProc.quiet = !!quiet;
        timerSetupProc.wanted = on;
        timerSetupProc.command = ["python3", "-I", "-c", `
import os, subprocess, sys
on, script, cfg = sys.argv[1] == "1", sys.argv[2], sys.argv[3]
unit_dir = os.path.expanduser("~/.config/systemd/user")
data_dir = os.path.expanduser("~/.local/share/caelestia")
svc_p = os.path.join(unit_dir, "caelestia-home-backup.service")
tmr_p = os.path.join(unit_dir, "caelestia-home-backup.timer")
script_p = os.path.join(data_dir, "home-backup.py")
def q(s):
    # systemd unit quoting: % and $ are expanded by systemd otherwise
    return chr(34) + s.replace(chr(92), chr(92) * 2).replace(chr(34), chr(92) + chr(34)).replace("%", "%%").replace("$", "$$") + chr(34)
if on:
    os.makedirs(unit_dir, exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    open(script_p, "w").write(script)
    open(svc_p, "w").write("[Unit]" + chr(10) + "Description=Caelestia home folder backup" + chr(10) + chr(10) + "[Service]" + chr(10) + "Type=oneshot" + chr(10) + "ExecStart=/usr/bin/python3 -I " + q(script_p) + " " + q(cfg) + chr(10))
    open(tmr_p, "w").write("[Unit]" + chr(10) + "Description=Daily home folder backup" + chr(10) + chr(10) + "[Timer]" + chr(10) + "OnCalendar=daily" + chr(10) + "Persistent=true" + chr(10) + chr(10) + "[Install]" + chr(10) + "WantedBy=timers.target" + chr(10))
    subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
    sys.exit(subprocess.run(["systemctl", "--user", "enable", "--now", "caelestia-home-backup.timer"]).returncode)
subprocess.run(["systemctl", "--user", "disable", "--now", "caelestia-home-backup.timer"], check=False)
for f in (svc_p, tmr_p, script_p):
    if os.path.exists(f):
        os.remove(f)
subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
`, on ? "1" : "0", backupScript, homeBackupConfig];
        timerSetupProc.running = false;
        timerSetupProc.running = true;
    }

    function configLabel(c: var): string {
        if (c.config === "root")
            return Tr.tr("System (/)");
        if (c.config === "home")
            return Tr.tr("Home (/home)");
        return `${c.config} (${c.subvolume})`;
    }

    title: Tr.tr("Snapshots")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            running: true
            command: ["sh", "-c", "command -v snapper >/dev/null && echo snapper"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.hasSnapper = text.includes("snapper");
                    if (root.hasSnapper) {
                        homeFsProc.running = true;
                        root.refresh();
                    } else {
                        root.checked = true;
                    }
                }
            }
        }

        Process {
            id: homeFsProc

            command: ["sh", "-c", "findmnt -n -o FSTYPE /home 2>/dev/null || true"]
            stdout: StdioCollector {
                onStreamFinished: root.homeIsBtrfs = text.trim() === "btrfs"
            }
        }

        Process {
            id: configsProc

            command: ["snapper", "--jsonout", "list-configs"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.configs = JSON.parse(text).configs ?? [];
                    } catch (e) {
                        root.configs = [];
                    }
                }
            }
        }

        Process {
            id: listProc

            command: ["snapper", "--jsonout", "-c", root.config, "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    root.checked = true;
                    try {
                        const data = JSON.parse(text);
                        root.snapshots = (data[root.config] ?? []).filter(s => s.number !== 0).reverse();
                        root.allowed = true;
                    } catch (e) {
                        root.allowed = false;
                        root.snapshots = [];
                    }
                }
            }
        }

        Process {
            id: configProc

            command: ["snapper", "--jsonout", "-c", root.config, "get-config"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.settings = JSON.parse(text);
                        root.limitHourly = parseInt(root.settings.TIMELINE_LIMIT_HOURLY ?? "5", 10) || 0;
                        root.limitDaily = parseInt(root.settings.TIMELINE_LIMIT_DAILY ?? "7", 10) || 0;
                        root.limitWeekly = parseInt(root.settings.TIMELINE_LIMIT_WEEKLY ?? "4", 10) || 0;
                        root.limitsDirty = false;
                    } catch (e) {
                        root.settings = {};
                    }
                }
            }
        }

        Process {
            id: snapperProc

            stderr: StdioCollector {
                id: snapperErr
            }
            onExited: (code, status) => {
                const toastMsg = root.pendingSnapperToast;
                root.pendingSnapperToast = "";
                if (code !== 0) {
                    const errLine = snapperErr.text.trim().split("\n").find(l => l.trim().length > 0) ?? "";
                    Toaster.toast(Tr.tr("Snapshot action failed"), errLine || Tr.tr("snapper exited with code %1").arg(code), "error");
                } else if (toastMsg) {
                    Toaster.toast(toastMsg, "", "delete_sweep");
                }
                root.refresh();
            }
        }

        // Only what this page needs (the full security check is much slower)
        Process {
            running: true
            command: [`${Paths.libdir}/caelestia-system`, "rollback-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const st = JSON.parse(text);
                        root.bootedSnapshot = !!st.bootedSnapshot;
                        root.rollbackBlocker = st.rollbackBlocker ?? "";
                    } catch (e) {}
                }
            }
        }

        Process {
            id: dailyStateProc

            running: true
            command: ["systemctl", "--user", "is-enabled", "caelestia-home-backup.timer"]
            onExited: code => {
                root.homeDailyActive = code === 0;
                // Units written by an older version had the destination built
                // in (and kept using an old one): written again in the new form
                if (root.homeDailyActive && !root.timerRefreshed && root.homeBackup.dest) {
                    root.timerRefreshed = true;
                    root.applyHomeDailyTimer(true, true);
                }
            }
        }

        Process {
            id: homeBackupDevProc

            // Line 1: same device as /home or not; line 2: the mount point the
            // folder is on (saved: a run checks that drive is there first)
            command: ["sh", "-c", "test -n \"$1\" && test -d \"$1\" || exit 0; test \"$(findmnt -n -o SOURCE -T /home 2>/dev/null)\" = \"$(findmnt -n -o SOURCE -T \"$1\" 2>/dev/null)\" && echo same || echo ok; findmnt -n -o TARGET -T \"$1\" 2>/dev/null", "sh", root.homeBackup.dest ?? ""]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n");
                    root.homeBackupSameDev = lines[0] === "same";
                    const mnt = (lines[1] ?? "").trim();
                    if (mnt && mnt !== (root.homeBackup.destMount ?? ""))
                        root.saveHomeBackup({
                            destMount: mnt
                        });
                }
            }
        }

        Process {
            id: rsyncProc

            stdout: SplitParser {
                onRead: line => {
                    const clean = line.trim();
                    if (clean)
                        root.homeBackupProgress = clean;
                }
            }
            stderr: StdioCollector {
                id: rsyncErr
            }
            // The script wrote lastRun/lastStatus/lastNote: read back
            onExited: code => {
                root.homeBackingUp = false;
                root.homeBackupProgress = "";
                homeBackupFile.reload();
                if (code === 0)
                    Toaster.toast(Tr.tr("Home folder backed up"), Paths.shortenHome(root.homeBackup.dest), "backup");
                else
                    Toaster.toast(Tr.tr("Home folder backup stopped"), rsyncErr.text.trim().split("\n").pop() || Tr.tr("rsync exited with code %1").arg(code), "error");
            }
        }

        Process {
            id: timerSetupProc

            property bool quiet
            property bool wanted

            stderr: StdioCollector {
                id: timerErr
            }
            onExited: code => {
                // The real state, whatever was asked
                dailyStateProc.running = false;
                dailyStateProc.running = true;
                if (code !== 0)
                    Toaster.toast(Tr.tr("Couldn't change the daily backup"), timerErr.text.trim().split("\n").pop() || Tr.tr("systemctl exited with code %1").arg(code), "error");
                else if (!quiet)
                    Toaster.toast(wanted ? Tr.tr("Daily home backup enabled") : Tr.tr("Daily home backup turned off"), "", "schedule");
            }
        }

        FileView {
            id: homeBackupFile

            path: root.homeBackupConfig
            printErrors: false
            // Timer runs write their result into it
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                try {
                    root.homeBackup = Object.assign({
                        dest: "",
                        excludeCaches: true,
                        daily: false,
                        lastRun: 0,
                        lastStatus: ""
                    }, JSON.parse(text()));
                    if (root.homeBackup.dest)
                        homeBackupDevProc.running = true;
                } catch (e) {}
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            visible: root.bootedSnapshot
            standalone: true
            fillColour: Colours.palette.m3secondaryContainer
            implicitHeight: Math.ceil(bootedSnapRow.implicitHeight) + Tokens.padding.large * 2

            RowLayout {
                id: bootedSnapRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "restore_page"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Booted from a snapshot")
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.rollbackBlocker ? Tr.tr("This start only: the next one is the normal system again. Making this snapshot the system for good isn't possible from here: this system starts from the subvolume its boot entry names. Files you need can be restored from a snapshot's page.") : Tr.tr("If everything works well here, you can make this snapshot the active system.")
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                TextButton {
                    // Only where it works (see rollbackBlocker)
                    visible: !root.rollbackBlocker
                    text: Tr.tr("Roll back to this snapshot…")
                    type: TextButton.Filled
                    onClicked: rollbackBannerDialog.ask({
                        header: Tr.tr("Roll back to this booted snapshot?"),
                        body: Tr.tr("snapper makes a new read-write snapshot of the system running now and makes it the default; the next start uses it."),
                        confirmLabel: Tr.tr("Roll back"),
                        icon: "restore",
                        onConfirm: () => Admin.run("snapper-rollback", [], Tr.tr("Roll back system snapshot"), ok => {
                            if (ok)
                                Toaster.toast(Tr.tr("Rollback set up"), Tr.tr("The next start uses this system"), "restore");
                        })
                    })
                }
            }
        }

        ConfirmDialog {
            id: rollbackBannerDialog

            hostFlickable: root.flickable
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: root.bootedSnapshot ? Tokens.spacing.small : 0
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.hasSnapper && root.configs.length > 1
            spacing: Tokens.spacing.small

            Repeater {
                model: root.configs

                TextButton {
                    required property var modelData

                    text: root.configLabel(modelData)
                    isToggle: true
                    followChecked: true
                    checked: root.config === modelData.config
                    type: TextButton.Tonal
                    onClicked: {
                        if (root.config !== modelData.config) {
                            root.config = modelData.config;
                            root.checked = false;
                            root.refresh();
                        }
                    }
                }
            }
        }

        RequirementRow {
            readonly property string what: Tr.tr("Set up system snapshots")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            visible: root.checked && !root.hasSnapper
            icon: "history"
            text: Tr.tr("Snapshots need snapper")
            subtext: busy ? Tr.tr("Installing and setting up…") : Tr.tr("And a btrfs system drive. Installs it, sets it up for the system drive and lets this account manage the snapshots (asks for your password).")
            actionText: busy ? "" : Tr.tr("Install")
            onAction: Admin.run("install", ["snapper"], what, ok => {
                if (ok)
                    Admin.run("snapper-setup", [], what, ok2 => {
                        if (ok2)
                            Admin.run("snapper-allow-me", ["root"], what, () => root.refresh());
                        else
                            root.refresh();
                    });
                else
                    root.refresh();
            })
        }

        // Not allowed yet: one sudo step
        ConnectedRect {
            Layout.fillWidth: true
            visible: root.checked && root.hasSnapper && !root.allowed
            implicitHeight: allowLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: allowLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Let this account manage snapshots")
                    font: Tokens.font.body.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("snapper only shows snapshots to the users its settings allow. Allowing yours (once, with your password) lets this page list, make and delete them.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    readonly property string what: Tr.tr("Let this account manage snapshots")

                    Layout.alignment: Qt.AlignRight
                    text: Tr.tr("Allow")
                    type: TextButton.Filled
                    disabled: Admin.jobs.some(j => j.what === what)
                    onClicked: Admin.run("snapper-allow-me", [root.config], what, () => root.refresh())
                }
            }
        }

        SectionHeader {
            visible: root.hasSnapper && root.homeIsBtrfs && !root.configs.some(c => c.config === "home")
            text: Tr.tr("Home folder")
        }

        InfoRow {
            visible: root.hasSnapper && root.homeIsBtrfs && !root.configs.some(c => c.config === "home")
            icon: "folder_special"
            label: Tr.tr("Home folder isn't included in system snapshots")
            subtext: Tr.tr("/home is on its own Btrfs partition, so system snapshots only protect system files. Set up /home snapshots to protect your personal files too.")
        }

        RowButton {
            readonly property string what: Tr.tr("Set up /home snapshots")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            visible: root.hasSnapper && root.homeIsBtrfs && !root.configs.some(c => c.config === "home")
            icon: "create_new_folder"
            text: what
            subtext: busy ? Tr.tr("Setting up…") : Tr.tr("Asks for your password once; creates a separate snapshot timeline for /home")
            disabled: busy
            onClicked: Admin.run("snapper-setup", ["home"], what, ok => {
                if (ok)
                    root.config = "home";
                root.refresh();
            })
        }

        SectionHeader {
            visible: root.allowed
            text: Tr.tr("Make a snapshot")
        }

        TextFieldRow {
            visible: root.allowed
            label: Tr.tr("Description")
            placeholderText: root.config === "home" ? Tr.tr("e.g. Before organizing files") : Tr.tr("e.g. Before changing drivers")
            value: root.newDescription
            onValueEdited: v => root.newDescription = v
        }

        RowButton {
            visible: root.allowed
            icon: "add_a_photo"
            text: Tr.tr("Make a snapshot now")
            subtext: root.config === "home" ? Tr.tr("Of your home folder (/home), as it is right now") : Tr.tr("Of the system drive, as it is right now")
            disabled: snapperProc.running
            onClicked: {
                root.snapper(["create", "--cleanup-algorithm", "number", "--description", root.newDescription || Tr.tr("Made in Settings")]);
                root.newDescription = "";
            }
        }

        SectionHeader {
            visible: root.allowed && root.snapshots.length > 0
            text: Tr.tr("Clean up snapshots")
        }

        SelectRow {
            id: cleanupAgeRow

            visible: root.allowed && root.snapshots.length > 0
            label: Tr.tr("Delete snapshots earlier than")
            menuItems: [age24hOpt, age3dOpt, age7dOpt, age14dOpt, age30dOpt, ageCustomOpt]
            active: Array.from(menuItems).find(i => i.key === root.cleanupAgePreset) ?? age7dOpt
            onSelected: item => root.cleanupAgePreset = item.key

            MenuItem {
                id: age24hOpt

                readonly property string key: "24h"

                text: Tr.tr("24 hours")
            }

            MenuItem {
                id: age3dOpt

                readonly property string key: "3d"

                text: Tr.tr("3 days")
            }

            MenuItem {
                id: age7dOpt

                readonly property string key: "7d"

                text: Tr.tr("7 days")
            }

            MenuItem {
                id: age14dOpt

                readonly property string key: "14d"

                text: Tr.tr("14 days")
            }

            MenuItem {
                id: age30dOpt

                readonly property string key: "30d"

                text: Tr.tr("30 days")
            }

            MenuItem {
                id: ageCustomOpt

                readonly property string key: "custom"

                text: Tr.tr("Custom…")
            }
        }

        StepperRow {
            visible: root.allowed && root.snapshots.length > 0 && root.cleanupAgePreset === "custom"
            label: Tr.tr("Older than (days)")
            from: 1
            to: 365
            value: root.cleanupCustomDays
            onMoved: v => root.cleanupCustomDays = Math.max(1, Math.round(v))
        }

        SelectRow {
            id: cleanupScopeRow

            visible: root.allowed && root.snapshots.length > 0
            label: Tr.tr("Which snapshots")
            menuItems: [scopeAllOpt, scopeHourlyOpt, scopeManualOpt]
            active: Array.from(menuItems).find(i => i.key === root.cleanupScope) ?? scopeAllOpt
            onSelected: item => root.cleanupScope = item.key

            MenuItem {
                id: scopeAllOpt

                readonly property string key: "all"

                text: Tr.tr("All snapshots")
            }

            MenuItem {
                id: scopeHourlyOpt

                readonly property string key: "hourly"

                text: Tr.tr("Hourly only")
            }

            MenuItem {
                id: scopeManualOpt

                readonly property string key: "manual"

                text: Tr.tr("Manual & updates")
            }
        }

        RowButton {
            visible: root.allowed && root.snapshots.length > 0
            icon: "delete_sweep"
            text: root.cleanupCandidates.length > 0
                ? Tr.trN("Delete %n old snapshot…", "Delete %n old snapshots…", root.cleanupCandidates.length)
                : Tr.tr("No snapshots earlier than %1").arg(root.cleanupAgeLabel)
            subtext: root.cleanupCandidates.length > 0
                ? Tr.tr("Earlier than %1 · Keeps the active, default, and newest snapshots").arg(root.cleanupAgeLabel)
                : Tr.tr("Always keeps the active, default, and newest snapshots")
            disabled: snapperProc.running || root.cleanupCandidates.length === 0
            onClicked: {
                const nums = root.cleanupCandidates.map(s => Number(s.number)).sort((a, b) => a - b);
                const firstNum = nums[0];
                const lastNum = nums[nums.length - 1];
                const cfgObj = root.configs.find(c => c.config === root.config);
                const cfgName = cfgObj ? root.configLabel(cfgObj) : root.config;
                const rangeText = firstNum === lastNum ? `#${firstNum}` : `#${firstNum}–#${lastNum}`;
                cleanupDialog.ask({
                    header: Tr.trN("Delete %n old snapshot?", "Delete %n old snapshots?", nums.length),
                    body: Tr.tr("Permanently deletes %1 snapshot(s) in %2 (%3) earlier than %4. The active, default, and newest snapshots are preserved.").arg(nums.length).arg(cfgName).arg(rangeText).arg(root.cleanupAgeLabel),
                    confirmLabel: Tr.trCtx("Delete", "button"),
                    icon: "delete_sweep",
                    onConfirm: () => {
                        root.pendingSnapperToast = Tr.trN("Deleted %n old snapshot", "Deleted %n old snapshots", nums.length);
                        root.snapper(["delete", "--sync", ...nums.map(n => String(n))]);
                    }
                });
            }
        }

        ConfirmDialog {
            id: cleanupDialog

            hostFlickable: root.flickable
        }

        SectionHeader {
            visible: root.allowed
            text: Tr.tr("Snapshots (%1)").arg(root.filteredSnapshots.length)
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.allowed && root.snapshots.length > 0
            spacing: Tokens.spacing.small

            Repeater {
                model: [["all", Tr.tr("All")], ["manual", Tr.tr("Manual & updates")], ["hourly", Tr.tr("Hourly")]]

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.snapFilter === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.snapFilter = modelData[0]
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.allowed && root.filteredSnapshots.length === 0
            text: root.snapshots.length === 0 ? Tr.tr("No snapshots yet") : Tr.tr("No snapshots match this filter.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        Repeater {
            id: snapList

            model: root.allowed ? root.filteredSnapshots : []

            ConnectedRect {
                id: snap

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: Math.ceil(snapLayout.implicitHeight) + Tokens.padding.medium * 2

                // Opens it: what changed since, restoring files, its files
                StateLayer {
                    onClicked: {
                        root.nState.selectedSnapperConfig = root.config;
                        root.nState.selectedSnapshot = snap.modelData.number;
                        root.nState.selectedSnapshotLabel = root.snapDisplayTitle(snap.modelData);
                        root.nState.openSubPage(3); // Storage's snapshot page
                    }
                }

                RowLayout {
                    id: snapLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: snap.modelData.type === "pre" || snap.modelData.type === "post" ? "update" : snap.modelData.cleanup === "timeline" ? "schedule" : "photo_camera"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.snapDisplayTitle(snap.modelData)
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `#${snap.modelData.number} · ${new Date(snap.modelData.date.replace(" ", "T")).toLocaleString(Qt.locale(), Locale.ShortFormat)}`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        text: Tr.trCtx("Delete", "button")
                        type: TextButton.Text
                        disabled: snapperProc.running
                        onClicked: {
                            deleteSnapDialog.targetSnap = snap.modelData;
                            deleteSnapDialog.open = true;
                        }
                    }
                }
            }
        }

        DialogRowButton {
            id: deleteSnapDialog

            property var targetSnap: null

            visible: false
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 300)
            icon: "delete"
            label: ""
            header: deleteSnapDialog.targetSnap ? Tr.tr("Delete snapshot #%1?").arg(deleteSnapDialog.targetSnap.number) : Tr.tr("Delete snapshot?")
            acceptLabel: Tr.trCtx("Delete", "button")
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: {
                            const desc = deleteSnapDialog.targetSnap?.description;
                            return desc ? Tr.tr("Permanently deletes snapshot #%1 (%2). This cannot be undone.").arg(deleteSnapDialog.targetSnap.number).arg(desc) : Tr.tr("Permanently deletes snapshot #%1. This cannot be undone.").arg(deleteSnapDialog.targetSnap?.number ?? "");
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: if (targetSnap)
                root.snapper(["delete", String(targetSnap.number)])
        }

        SectionHeader {
            visible: root.allowed
            text: Tr.tr("Automatic snapshots")
        }

        InfoRow {
            visible: root.allowed
            icon: "schedule"
            label: Tr.tr("Hourly snapshots")
            subtext: root.settings.TIMELINE_CREATE === "yes" ? Tr.tr("Keeps %1 hourly, %2 daily, %3 weekly").arg(root.settings.TIMELINE_LIMIT_HOURLY ?? "?").arg(root.settings.TIMELINE_LIMIT_DAILY ?? "?").arg(root.settings.TIMELINE_LIMIT_WEEKLY ?? "?") : ""
            value: root.settings.TIMELINE_CREATE === "yes" ? Tr.tr("On") : Tr.tr("Off")
        }

        RowButton {
            readonly property string what: root.settings.TIMELINE_CREATE === "yes" ? Tr.tr("Turn hourly snapshots off") : Tr.tr("Turn hourly snapshots on")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            visible: root.allowed
            icon: root.settings.TIMELINE_CREATE === "yes" ? "timer_off" : "timer"
            text: what
            subtext: busy ? Tr.tr("Applying…") : ""
            disabled: busy
            onClicked: Admin.run("snapper-timeline", [root.config, root.settings.TIMELINE_CREATE === "yes" ? "no" : "yes"], what, () => root.refresh())
        }

        StepperRow {
            visible: root.allowed && root.settings.TIMELINE_CREATE === "yes"
            label: Tr.tr("Hourly snapshots to keep")
            from: 0
            to: 50
            value: root.limitHourly
            onMoved: v => {
                root.limitHourly = Math.round(v);
                root.limitsDirty = true;
            }
        }

        StepperRow {
            visible: root.allowed && root.settings.TIMELINE_CREATE === "yes"
            label: Tr.tr("Daily snapshots to keep")
            from: 0
            to: 50
            value: root.limitDaily
            onMoved: v => {
                root.limitDaily = Math.round(v);
                root.limitsDirty = true;
            }
        }

        StepperRow {
            visible: root.allowed && root.settings.TIMELINE_CREATE === "yes"
            label: Tr.tr("Weekly snapshots to keep")
            from: 0
            to: 50
            value: root.limitWeekly
            onMoved: v => {
                root.limitWeekly = Math.round(v);
                root.limitsDirty = true;
            }
        }

        RowButton {
            readonly property string what: Tr.tr("Save snapshot keep limits")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)

            visible: root.allowed && root.settings.TIMELINE_CREATE === "yes" && root.limitsDirty
            icon: "save"
            text: what
            subtext: busy ? Tr.tr("Saving…") : Tr.tr("%1 hourly · %2 daily · %3 weekly").arg(root.limitHourly).arg(root.limitDaily).arg(root.limitWeekly)
            disabled: busy
            onClicked: Admin.run("snapper-limits", [root.config, String(root.limitHourly), String(root.limitDaily), String(root.limitWeekly)], what, ok => {
                if (ok) {
                    root.limitsDirty = false;
                    root.refresh();
                }
            })
        }

        InfoRow {
            groupStart: true
            visible: root.allowed && root.config === "root"
            icon: "restore"
            label: Tr.tr("Restore whole system")
            subtext: root.rollbackBlocker ? Tr.tr("To start an earlier state once, pick a snapshot under CachyOS in the boot menu (F2 or Insert). Single files: open a snapshot above and restore them. Making a snapshot the system for good needs the boot entry changed: %1.").arg(root.rollbackBlocker) : Tr.tr("Pick a snapshot under CachyOS in the boot menu (F2 or Insert) to test it; started from it, this page offers to make it the system.")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            visible: root.allowed && root.config === "home"
            text: Tr.tr("Click any snapshot above to browse its files or restore older versions.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // Home folder rsync backup to another drive or folder
        SectionHeader {
            text: Tr.tr("Home folder backup")
        }

        FolderPickerRow {
            icon: "drive_file_move"
            label: Tr.tr("Backup destination")
            placeholderText: Tr.tr("Choose a folder on another drive or backup disk")
            value: root.homeBackup.dest ?? ""
            subtext: {
                const notes = [];
                if (root.homeBackupInHome)
                    notes.push(Tr.tr("Inside your home folder: the backup folder itself is left out"));
                if (root.homeBackupSameDev)
                    notes.push(Tr.tr("Warning: on the same partition as /home — a drive failure could affect both"));
                if (root.homeBackup.lastStatus === "error")
                    notes.push(Tr.tr("Last backup failed: %1").arg(root.homeBackup.lastNote || Tr.tr("unknown error")));
                else if (root.homeBackup.lastRun > 0)
                    notes.push(Tr.tr("Last backup: %1").arg(Qt.formatDateTime(new Date(root.homeBackup.lastRun * 1000), "d MMM yyyy, HH:mm")) + (root.homeBackup.lastNote === "vanished" ? Tr.tr(" (some files changed while copying)") : ""));
                return notes.join(" · ");
            }
            canReset: !!(root.homeBackup.dest)
            // A new folder: its drive is found again (destMount) before any run
            onPicked: path => root.saveHomeBackup({
                    dest: path,
                    destMount: ""
                })
            // No destination: no timer either
            onResetClicked: {
                root.saveHomeBackup({
                    dest: "",
                    destMount: "",
                    daily: false
                });
                if (root.homeDailyActive)
                    root.applyHomeDailyTimer(false, false);
            }
        }

        ToggleRow {
            text: Tr.tr("Exclude caches & Steam games")
            subtext: Tr.tr("Skips ~/.cache, Steam game downloads, Trash and node_modules")
            checked: root.homeBackup.excludeCaches !== false
            onToggled: root.saveHomeBackup({
                excludeCaches: checked
            })
        }

        RowButton {
            icon: root.homeBackingUp ? "stop_circle" : "backup"
            text: root.homeBackingUp ? Tr.tr("Cancel backup") : Tr.tr("Back up /home now")
            subtext: root.homeBackingUp ? (root.homeBackupProgress || Tr.tr("Copying files with rsync…")) : root.homeBackup.dest ? Tr.tr("Syncs /home into %1/home-backup").arg(Paths.shortenHome(root.homeBackup.dest)) : Tr.tr("Pick a backup destination above first")
            disabled: !root.homeBackingUp && !root.homeBackup.dest
            onClicked: root.homeBackingUp ? root.cancelHomeBackup() : root.runHomeBackupNow()
        }

        ToggleRow {
            text: Tr.tr("Automatic daily backup")
            subtext: root.homeDailyActive ? Tr.tr("Runs daily via systemd user timer (caelestia-home-backup.timer)") : Tr.tr("Creates a daily user timer syncing /home to the chosen folder")
            disabled: !root.homeBackup.dest && !root.homeDailyActive
            checked: root.homeDailyActive
            onToggled: {
                const want = checked;
                // Shows the real state again once it's known (also when it fails)
                checked = Qt.binding(() => root.homeDailyActive);
                root.saveHomeBackup({
                    daily: want
                });
                root.applyHomeDailyTimer(want, false);
            }
        }
    }
}
