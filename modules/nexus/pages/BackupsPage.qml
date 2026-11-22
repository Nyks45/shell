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
    property int limitHourly: 5
    property int limitDaily: 7
    property int limitWeekly: 4
    property bool limitsDirty: false
    property bool bootedSnapshot: false
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

    readonly property var filteredSnapshots: {
        if (snapFilter === "hourly")
            return snapshots.filter(s => s.cleanup === "timeline");
        if (snapFilter === "manual")
            return snapshots.filter(s => s.cleanup !== "timeline");
        return snapshots;
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

    function _rsyncArgs(): list<string> {
        const homeDir = Quickshell.env("HOME") || "";
        const target = `${homeBackup.dest.replace(/\/$/, "")}/home-backup/`;
        const args = ["-aHAX", "--delete", "--info=progress2", "--no-inc-recursive"];
        if (homeBackup.excludeCaches !== false) {
            for (const ex of [".cache", ".local/share/Steam/steamapps", ".local/share/Trash", "node_modules"])
                args.push("--exclude", ex);
        }
        args.push(`${homeDir}/`, target);
        return args;
    }

    function runHomeBackupNow(): void {
        if (!homeBackup.dest || homeBackingUp)
            return;
        homeBackupProgress = Tr.tr("Starting backup…");
        homeBackingUp = true;
        rsyncProc.command = ["sh", "-c", "mkdir -p \"$1\" && shift && exec rsync \"$@\"", "sh", `${homeBackup.dest.replace(/\/$/, "")}/home-backup`, ..._rsyncArgs()];
        rsyncProc.running = true;
    }

    function cancelHomeBackup(): void {
        if (homeBackingUp)
            rsyncProc.running = false;
    }

    function applyHomeDailyTimer(enabled: bool): void {
        if (enabled && !homeBackup.dest)
            return;
        const cfg = JSON.stringify({
            dest: homeBackup.dest,
            excludeCaches: homeBackup.excludeCaches !== false,
            enabled
        });
        timerSetupProc.command = ["python3", "-I", "-c", `
import json, os, shlex, subprocess
d = json.loads(os.environ["CAELESTIA_HB"])
cfg_dir = os.path.expanduser("~/.config/systemd/user")
os.makedirs(cfg_dir, exist_ok=True)
svc_p = os.path.join(cfg_dir, "caelestia-home-backup.service")
tmr_p = os.path.join(cfg_dir, "caelestia-home-backup.timer")
if d["enabled"] and d["dest"]:
    target = d["dest"].rstrip("/") + "/home-backup/"
    home = os.path.expanduser("~").rstrip("/") + "/"
    args = ["/usr/bin/rsync", "-aHAX", "--delete"]
    if d.get("excludeCaches", True):
        for ex in (".cache", ".local/share/Steam/steamapps", ".local/share/Trash", "node_modules"):
            args.extend(["--exclude", ex])
    args.extend([home, target])
    cmd = "mkdir -p " + shlex.quote(target) + " && exec " + " ".join(shlex.quote(a) for a in args)
    open(svc_p, "w").write("[Unit]\\nDescription=Caelestia Home Folder Backup\\n\\n[Service]\\nType=oneshot\\nExecStart=/usr/bin/sh -c " + json.dumps(cmd) + "\\n")
    open(tmr_p, "w").write("[Unit]\\nDescription=Daily Home Folder Backup\\n\\n[Timer]\\nOnCalendar=daily\\nPersistent=true\\n\\n[Install]\\nWantedBy=timers.target\\n")
    subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
    subprocess.run(["systemctl", "--user", "enable", "--now", "caelestia-home-backup.timer"], check=True)
else:
    subprocess.run(["systemctl", "--user", "disable", "--now", "caelestia-home-backup.timer"], check=False)
`, ...[]];
        timerSetupProc.environment = ({
                CAELESTIA_HB: cfg
            });
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
                if (code !== 0) {
                    const errLine = snapperErr.text.trim().split("\n").find(l => l.trim().length > 0) ?? "";
                    Toaster.toast(Tr.tr("Snapshot action failed"), errLine || Tr.tr("snapper exited with code %1").arg(code), "error");
                }
                root.refresh();
            }
        }

        Process {
            running: true
            command: [`${Paths.libdir}/caelestia-system`, "security-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.bootedSnapshot = !!JSON.parse(text).bootedSnapshot;
                    } catch (e) {}
                }
            }
        }

        Process {
            running: true
            command: ["systemctl", "--user", "is-enabled", "caelestia-home-backup.timer"]
            onExited: code => root.homeDailyActive = code === 0
        }

        Process {
            id: homeBackupDevProc

            command: ["sh", "-c", "test -n \"$1\" && test -d \"$1\" && test \"$(findmnt -n -o SOURCE -T /home 2>/dev/null)\" = \"$(findmnt -n -o SOURCE -T \"$1\" 2>/dev/null)\" && echo same || echo ok", "sh", root.homeBackup.dest ?? ""]
            stdout: StdioCollector {
                onStreamFinished: root.homeBackupSameDev = text.trim() === "same"
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
            onExited: code => {
                root.homeBackingUp = false;
                if (code === 0) {
                    root.saveHomeBackup({
                        lastRun: Math.floor(Date.now() / 1000),
                        lastStatus: "ok"
                    });
                    Toaster.toast(Tr.tr("Home folder backed up"), Paths.shortenHome(root.homeBackup.dest), "backup");
                } else {
                    root.saveHomeBackup({
                        lastStatus: "error"
                    });
                    Toaster.toast(Tr.tr("Home folder backup stopped"), Tr.tr("rsync exited with code %1").arg(code), "error");
                }
                root.homeBackupProgress = "";
            }
        }

        Process {
            id: timerSetupProc

            onExited: code => {
                root.homeDailyActive = code === 0 && (root.homeBackup.daily ?? false);
                if (code === 0)
                    Toaster.toast(root.homeDailyActive ? Tr.tr("Daily home backup enabled") : Tr.tr("Daily home backup turned off"), "", "schedule");
            }
        }

        FileView {
            id: homeBackupFile

            path: `${Paths.config}/home-backup.json`
            printErrors: false
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
            color: Colours.palette.m3secondaryContainer
            implicitHeight: bootedSnapRow.implicitHeight + Tokens.padding.large * 2

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
                        text: Tr.tr("If everything works well here, you can make this snapshot the active system.")
                        color: Colours.palette.m3onSecondaryContainer
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                TextButton {
                    text: Tr.tr("Roll back to this snapshot…")
                    type: TextButton.Filled
                    onClicked: rollbackBannerDialog.ask({
                        header: Tr.tr("Roll back to this booted snapshot?"),
                        body: Tr.tr("Sets this read-write snapshot as the default system root in Btrfs and updates the boot menu. Restart to switch to it cleanly."),
                        confirmLabel: Tr.tr("Roll back"),
                        icon: "restore",
                        onConfirm: () => Admin.run("snapper-rollback", [], Tr.tr("Roll back system snapshot"), ok => {
                            if (ok)
                                Toaster.toast(Tr.tr("Rollback scheduled"), Tr.tr("Restart to boot into the rolled-back system"), "restore");
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
            visible: root.allowed
            text: Tr.tr("Snapshots (%1)").arg(root.filteredSnapshots.length)
        }

        Flow {
            Layout.fillWidth: true
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
                implicitHeight: snapLayout.implicitHeight + Tokens.padding.medium * 2

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
            subtext: Tr.tr("Pick a snapshot under CachyOS in the boot menu (F2 or Insert) to test it, then run `sudo snapper rollback` to make that snapshot the active system.")
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
            subtext: root.homeBackupSameDev ? Tr.tr("Warning: this folder is on the same partition as /home — a drive failure could affect both") : root.homeBackup.lastRun > 0 ? Tr.tr("Last backup: %1").arg(Qt.formatDateTime(new Date(root.homeBackup.lastRun * 1000), "d MMM yyyy, HH:mm")) : ""
            canReset: !!(root.homeBackup.dest)
            onPicked: path => root.saveHomeBackup({
                    dest: path
                })
            onResetClicked: root.saveHomeBackup({
                dest: "",
                daily: false
            })
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
                root.saveHomeBackup({
                    daily: checked
                });
                root.applyHomeDailyTimer(checked);
            }
        }
    }
}
