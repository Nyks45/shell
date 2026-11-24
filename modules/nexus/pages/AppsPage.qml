pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // The system defaults (xdg-settings / xdg-mime), as desktop entry ids
    property string browserId
    property string editorId
    property bool allowRegexPatterns: false
    // Defaults by file type (xdg-mime) and matching desktop entry ids per role/group
    property var mimeDefaults: ({})
    property var mimeHandlers: ({})
    readonly property var mimeGroups: ({
            images: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/svg+xml", "image/tiff", "image/avif", "image/heic", "image/x-icon"],
            video: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg", "video/x-flv"],
            music: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/wav", "audio/mp4", "audio/aac", "audio/opus", "audio/x-vorbis+ogg"],
            pdf: ["application/pdf"],
            archives: ["application/zip", "application/x-tar", "application/x-7z-compressed", "application/vnd.rar", "application/x-rar", "application/gzip", "application/x-compressed-tar", "application/x-xz-compressed-tar", "application/zstd", "application/x-bzip2"],
            email: ["x-scheme-handler/mailto"]
        })
    readonly property list<string> textTypes: ["text/plain", "text/markdown", "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/x-c++hdr", "text/x-python", "text/x-shellscript", "application/x-shellscript", "application/json", "application/xml", "application/toml", "text/x-lua", "application/x-yaml", "text/x-log"]
    readonly property string _desktopScanPy: `import configparser, glob, json, os, re, subprocess
groups = {
    "images": {"image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/svg+xml", "image/tiff", "image/avif", "image/heic", "image/x-icon"},
    "video": {"video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg", "video/x-flv"},
    "music": {"audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/wav", "audio/mp4", "audio/aac", "audio/opus", "audio/x-vorbis+ogg"},
    "pdf": {"application/pdf"},
    "archives": {"application/zip", "application/x-tar", "application/x-7z-compressed", "application/vnd.rar", "application/x-rar", "application/gzip", "application/x-compressed-tar", "application/x-xz-compressed-tar", "application/zstd", "application/x-bzip2"},
    "email": {"x-scheme-handler/mailto"},
}
first_mime = {k: sorted(v)[0] for k, v in groups.items()}
first_mime.update({"images": "image/png", "video": "video/mp4", "music": "audio/mpeg", "pdf": "application/pdf", "archives": "application/zip", "email": "x-scheme-handler/mailto"})
defaults = {}
for k, mt in first_mime.items():
    r = subprocess.run(["xdg-mime", "query", "default", mt], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    defaults[k] = r.stdout.strip()
app_dirs = [
    os.path.expanduser("~/.local/share/applications"),
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/usr/local/share/applications",
    "/usr/share/applications",
    "/var/lib/flatpak/exports/share/applications",
]
seen = {}
for d in app_dirs:
    if not os.path.isdir(d):
        continue
    for f in sorted(glob.glob(os.path.join(d, "*.desktop"))):
        did = os.path.basename(f)[:-8]
        if did not in seen:
            seen[did] = f
handlers = {k: [] for k in list(groups.keys()) + ["browser", "editor", "files", "terminal", "mixer", "playback"]}
mixer_re = re.compile(r"(pavucontrol|easyeffects|qpwgraph|helvum|pulsemixer|alsamixer|kmix|veromix|mixertui|volume|mixer)", re.I)
cam_re = re.compile(r"(qv4l2|qvidcap)", re.I)
for did, path in seen.items():
    cp = configparser.ConfigParser(interpolation=None)
    try:
        cp.read(path, encoding="utf-8")
    except Exception:
        continue
    if "Desktop Entry" not in cp:
        continue
    sec = cp["Desktop Entry"]
    if sec.get("Type", "Application") != "Application":
        continue
    if sec.get("Hidden", "").lower() == "true" or sec.get("NoDisplay", "").lower() == "true":
        continue
    mimes = {m.strip().lower() for m in sec.get("MimeType", "").split(";") if m.strip()}
    cats = {c.strip() for c in sec.get("Categories", "").split(";") if c.strip()}
    name = sec.get("Name", "")
    for gk, gm in groups.items():
        if (mimes & gm) or (gk == "email" and "Email" in cats) or (gk == "archives" and "Archiving" in cats):
            handlers[gk].append(did)
    if (mimes & {"x-scheme-handler/http", "x-scheme-handler/https", "text/html"}) or ("WebBrowser" in cats):
        handlers["browser"].append(did)
    if (mimes & {"text/plain", "text/markdown"}) or ("TextEditor" in cats):
        handlers["editor"].append(did)
    if ("inode/directory" in mimes) or ("FileManager" in cats):
        handlers["files"].append(did)
    if "TerminalEmulator" in cats:
        handlers["terminal"].append(did)
    if ("Mixer" in cats or mixer_re.search(did) or mixer_re.search(name)) and not cam_re.search(did):
        handlers["mixer"].append(did)
    if ("Player" in cats or (("AudioVideo" in cats or "Audio" in cats or "Video" in cats) and (mimes & (groups["video"] | groups["music"])))) and not cam_re.search(did):
        handlers["playback"].append(did)
print(json.dumps({"defaults": defaults, "handlers": handlers}))
`

    // A desktop entry's command for the config (no %u-style placeholders)
    function commandOf(app: var): string {
        return (app.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a)).join(" ");
    }

    function nameOf(id: string): string {
        return DesktopEntries.byId(id.replace(/\.desktop$/, ""))?.name ?? id.replace(/\.desktop$/, "");
    }

    function friendlyCommandName(cmd: var): string {
        if (!cmd || cmd.length === 0)
            return Tr.tr("Not set");
        const curStr = cmd.join(" ");
        if (curStr.includes("audio openMixer"))
            return Tr.tr("Caelestia Sound Mixer (built in)");
        const curBin = String(cmd[0] ?? "").split("/").pop();
        const all = [...DesktopEntries.applications.values];
        const visibleApps = all.filter(a => !a.noDisplay);
        const labelFor = a => (curBin && a.name.toLowerCase() === curBin.toLowerCase() && a.genericName) ? `${a.genericName} (${a.name})` : a.name;
        for (const list of [visibleApps, all]) {
            const exact = list.find(a => commandOf(a) === curStr || a.command.join(" ") === curStr);
            if (exact?.name)
                return labelFor(exact);
            if (curBin) {
                const byBin = list.find(a => String(a.command[0] ?? "").split("/").pop() === curBin);
                if (byBin?.name)
                    return labelFor(byBin);
            }
        }
        return curStr;
    }

    title: Tr.tr("Apps")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Default applications
        SectionHeader {
            text: Tr.tr("Default applications")
        }

        DefaultRow {
            icon: "terminal"
            label: Tr.trCtx("Terminal", "default app category")
            category: "TerminalEmulator"
            handlerKey: "terminal"
            status: root.friendlyCommandName(GlobalConfig.general.apps.terminal)
            currentCommand: GlobalConfig.general.apps.terminal
            onSelected: app => GlobalConfig.general.apps.terminal = app.command
        }

        DefaultRow {
            icon: "volume_up"
            label: Tr.trCtx("Sound mixer", "default app category")
            handlerKey: "mixer"
            builtInApp: ({
                id: "",
                name: Tr.tr("Caelestia Sound Mixer (built in)"),
                genericName: "",
                icon: "audio-volume-high",
                command: ["qs", "-c", "caelestia", "ipc", "call", "audio", "openMixer"]
            })
            status: root.friendlyCommandName(GlobalConfig.general.apps.audio)
            currentCommand: GlobalConfig.general.apps.audio
            onSelected: app => GlobalConfig.general.apps.audio = app.command
        }

        DefaultRow {
            icon: "play_circle"
            label: Tr.trCtx("Media playback", "default app category")
            category: "Player"
            handlerKey: "playback"
            status: root.friendlyCommandName(GlobalConfig.general.apps.playback)
            currentCommand: GlobalConfig.general.apps.playback
            onSelected: app => GlobalConfig.general.apps.playback = app.command
        }

        DefaultRow {
            icon: "folder"
            label: Tr.trCtx("File manager", "default app category")
            category: "FileManager"
            handlerKey: "files"
            status: root.friendlyCommandName(GlobalConfig.general.apps.explorer)
            currentCommand: GlobalConfig.general.apps.explorer
            onSelected: app => GlobalConfig.general.apps.explorer = app.command
        }

        DefaultRow {
            icon: "language"
            label: Tr.trCtx("Web browser", "default app category")
            category: "WebBrowser"
            handlerKey: "browser"
            status: root.browserId ? root.nameOf(root.browserId) : Tr.tr("Not set")
            currentId: root.browserId
            onSelected: app => {
                root.browserId = `${app.id}.desktop`;
                HyprSettings.setVar("browser", root.commandOf(app));
                Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", `${app.id}.desktop`]);
            }
        }

        DefaultRow {
            icon: "edit_note"
            label: Tr.trCtx("Text editor", "default app category")
            category: "TextEditor"
            handlerKey: "editor"
            status: root.editorId ? root.nameOf(root.editorId) : Tr.tr("Not set")
            currentId: root.editorId
            onSelected: app => {
                root.editorId = `${app.id}.desktop`;
                HyprSettings.setVar("editor", root.commandOf(app));
                Quickshell.execDetached(["xdg-mime", "default", `${app.id}.desktop`, ...root.textTypes]);
            }
        }

        // By file type
        SectionHeader {
            text: Tr.tr("Open files with")
        }

        DefaultRow {
            icon: "image"
            label: Tr.trCtx("Images", "default app category")
            group: "images"
        }

        DefaultRow {
            icon: "movie"
            label: Tr.trCtx("Videos", "default app category")
            group: "video"
        }

        DefaultRow {
            icon: "music_note"
            label: Tr.trCtx("Music", "default app category")
            group: "music"
        }

        DefaultRow {
            icon: "picture_as_pdf"
            label: Tr.trCtx("PDF documents", "default app category")
            group: "pdf"
        }

        DefaultRow {
            icon: "folder_zip"
            label: Tr.trCtx("Archives", "default app category")
            group: "archives"
        }

        DefaultRow {
            icon: "mail"
            label: Tr.trCtx("Email", "default app category")
            group: "email"
        }

        Process {
            id: mimeProc

            running: true
            command: ["python3", "-I", "-c", root._desktopScanPy]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        root.mimeDefaults = data.defaults ?? {};
                        root.mimeHandlers = data.handlers ?? {};
                    } catch (e) {}
                }
            }
        }

        // Library
        SectionHeader {
            text: Tr.trCtx("Library", "app library")
        }

        NavRow {
            icon: "apps"
            text: Tr.tr("All apps")
            subtext: Tr.tr("Browse installed apps, set favourites and hidden")
            onClicked: root.nState.openSubPage(1)
        }

        // The launcher's lists of app id patterns (regular expressions)
        SectionHeader {
            text: Tr.tr("Pinned in the launcher")
        }

        AppListEditor {
            hostFlickable: root.flickable
            values: GlobalConfig.launcher.favouriteApps
            addLabel: Tr.tr("Pin an app")
            emptyText: Tr.tr("None: pin apps from All apps, or add one here")
            pickerHeader: Tr.tr("Pin an app in the launcher")
            allowCustom: root.allowRegexPatterns
            validate: t => {
                try {
                    new RegExp(t);
                    return true;
                } catch (e) {
                    return false;
                }
            }
            onEdited: v => GlobalConfig.launcher.favouriteApps = v
        }

        SectionHeader {
            text: Tr.tr("Hidden from the launcher")
        }

        AppListEditor {
            hostFlickable: root.flickable
            values: GlobalConfig.launcher.hiddenApps
            addLabel: Tr.tr("Hide an app")
            emptyText: Tr.tr("No apps hidden")
            pickerHeader: Tr.tr("Hide an app from the launcher")
            allowCustom: root.allowRegexPatterns
            validate: t => {
                try {
                    new RegExp(t);
                    return true;
                } catch (e) {
                    return false;
                }
            }
            onEdited: v => GlobalConfig.launcher.hiddenApps = v
        }

        ToggleRow {
            groupStart: true
            text: Tr.tr("Advanced: allow custom regex patterns")
            subtext: Tr.tr("Let you type regular expressions matching app IDs when pinning or hiding")
            checked: root.allowRegexPatterns
            onToggled: root.allowRegexPatterns = checked
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            running: true
            command: ["sh", "-c", "xdg-settings get default-web-browser; xdg-mime query default text/plain"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [browser, editor] = text.split("\n");
                    root.browserId = browser?.trim() ?? "";
                    root.editorId = editor?.trim() ?? "";
                }
            }
        }
    }

    component DefaultRow: PopupRow {
        id: row

        // A group of file types (mimeGroups) this row sets the default app for
        property string group

        // Only apps of this kind (a desktop file category), when there are any
        property string category
        // Key into root.mimeHandlers (defaults to group)
        property string handlerKey: group

        property var currentCommand: []
        property var builtInApp: null
        property string currentId: group ? (root.mimeDefaults[group] ?? "") : ""
        property string query
        property bool showAllApps: false

        readonly property var allVisibleApps: [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
        readonly property var allApps: {
            if (!popup.active)
                return [];
            const all = allVisibleApps;
            let apps;
            if (showAllApps) {
                apps = all;
            } else {
                const key = handlerKey || group;
                const scanned = key && Array.isArray(root.mimeHandlers[key]) ? new Set(root.mimeHandlers[key]) : null;
                apps = all.filter(a => {
                    if (isCurrent(a))
                        return true;
                    if (scanned && scanned.has(a.id))
                        return true;
                    if (category && (a.categories ?? []).includes(category))
                        return true;
                    return false;
                });
            }
            const favourited = new Set(apps.filter(a => !!a.id && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, a.id)));
            const sorted = [...apps].sort((a, b) => (favourited.has(b) - favourited.has(a)) || a.name.localeCompare(b.name));
            return builtInApp ? [builtInApp, ...sorted] : sorted;
        }
        readonly property bool showSearch: allApps.length > 8
        readonly property var filteredApps: {
            const q = showSearch ? query.trim().toLowerCase() : "";
            if (!q)
                return allApps;
            return allApps.filter(a => (a.name ?? "").toLowerCase().includes(q)
                || (a.id ?? "").toLowerCase().includes(q)
                || (a.genericName ?? "").toLowerCase().includes(q));
        }
        readonly property real rowH: Math.ceil(Math.max(itemMetrics.height, 20)) + Tokens.padding.small * 2
        readonly property real searchH: Math.ceil(itemMetrics.height) + Tokens.padding.small * 2
        readonly property real footerH: Math.ceil(toggleMetrics.height) + Tokens.padding.extraSmall * 2
        readonly property real listH: filteredApps.length > 0 ? Math.min(240, filteredApps.length * rowH + Math.max(0, filteredApps.length - 1) * 2) : 48

        function isCurrent(app: var): bool {
            if (currentId) {
                const target = currentId.replace(/\.desktop$/, "");
                if ((app.id ?? "").replace(/\.desktop$/, "") === target)
                    return true;
            }
            if (currentCommand && currentCommand.length > 0) {
                const curStr = currentCommand.join(" ");
                const appCmd = root.commandOf(app);
                if (appCmd === curStr || (app.command ?? []).join(" ") === curStr)
                    return true;
                const curBin = String(currentCommand[0] ?? "").split("/").pop();
                const appBin = String((app.command ?? [])[0] ?? "").split("/").pop();
                if (curBin && appBin && curBin !== "qs" && curBin === appBin)
                    return true;
            }
            return false;
        }

        signal selected(app: var)

        status: group ? (root.mimeDefaults[group] ? root.nameOf(root.mimeDefaults[group]) : Tr.tr("Not set")) : ""
        onSelected: app => {
            if (!group)
                return;
            const next = Object.assign({}, root.mimeDefaults);
            next[group] = `${app.id}.desktop`;
            root.mimeDefaults = next;
            Quickshell.execDetached(["xdg-mime", "default", `${app.id}.desktop`, ...root.mimeGroups[group]]);
        }
        onOpenChanged: {
            if (open) {
                query = "";
                if (showSearch)
                    Qt.callLater(() => (popup.item as Item)?.forceActiveFocus());
            }
        }

        Connections {
            function onActiveChanged(): void {
                if (!row.popup.active) {
                    row.query = "";
                    row.showAllApps = false;
                }
            }

            target: row.popup
        }

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popupWidth: showSearch
            ? 256
            : Math.round(CUtils.clamp(allApps.reduce((m, a) => Math.max(m, (a.name ?? "").length), 0) * itemMetrics.averageCharacterWidth + 20 + Tokens.spacing.small + Tokens.padding.medium * 2 + 28, 196, 260))
        popupHeight: (showSearch ? (searchH + Tokens.spacing.small) : 0) + listH + Tokens.spacing.extraSmall + footerH
        maxPopupHeight: showSearch ? 320 : 296

        FontMetrics {
            id: itemMetrics

            font: Tokens.font.body.small
        }

        FontMetrics {
            id: toggleMetrics

            font: Tokens.font.label.medium
        }

        popupContent: Component {
            ColumnLayout {
                id: popupCol

                spacing: Tokens.spacing.small
                onActiveFocusChanged: if (activeFocus && row.showSearch)
                    filter.forceActiveFocus()

                SearchBar {
                    id: filter

                    Layout.fillWidth: true
                    visible: row.showSearch
                    implicitHeight: row.searchH
                    placeholderText: Tr.tr("Search apps")
                    font: Tokens.font.body.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small
                    bg.color: Colours.tPalette.m3surfaceContainerLowest
                    bg.border.width: 1
                    bg.border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
                    onTextChanged: row.query = text
                    Keys.onEscapePressed: row.open = false
                    onAccepted: {
                        if (row.filteredApps.length > 0) {
                            row.open = false;
                            row.selected(row.filteredApps[0]);
                        }
                    }

                    Connections {
                        function onQueryChanged(): void {
                            if (filter.text !== row.query)
                                filter.text = row.query;
                        }

                        target: row
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    VerticalFadeListView {
                        id: list

                        anchors.fill: parent
                        clip: true
                        fadeAmount: 0.08
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: row.filteredApps

                        delegate: StyledRect {
                            id: appItem

                            required property var modelData
                            required property int index
                            readonly property bool current: row.isCurrent(modelData)

                            width: ListView.view.width
                            implicitHeight: row.rowH
                            radius: height / 2
                            color: current ? Colours.palette.m3secondaryContainer : "transparent"

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                color: appItem.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                onClicked: {
                                    row.open = false;
                                    row.selected(appItem.modelData);
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.medium
                                spacing: Tokens.spacing.small

                                ThemedIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    asynchronous: true
                                    monochrome: true
                                    colour: appItem.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    implicitSize: 20
                                    source: Quickshell.iconPath(appItem.modelData.icon, "image-missing")
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: appItem.modelData.name
                                    font: Tokens.font.body.small
                                    color: appItem.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: !!appItem.modelData.id && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, appItem.modelData.id)
                                    text: "favorite"
                                    fill: 1
                                    color: appItem.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                                    fontStyle: Tokens.font.icon.small
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: row.filteredApps.length === 0
                        text: row.showAllApps ? Tr.tr("No apps match") : Tr.tr("No matching apps")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }

                TextButton {
                    Layout.alignment: Qt.AlignHCenter
                    horizontalPadding: Tokens.padding.small
                    verticalPadding: Tokens.padding.extraSmall
                    font: Tokens.font.label.medium
                    type: TextButton.Text
                    text: row.showAllApps ? Tr.tr("Show matching apps only") : Tr.tr("Show all apps (%1)").arg(row.allVisibleApps.length)
                    onClicked: {
                        row.query = "";
                        row.showAllApps = !row.showAllApps;
                    }
                }
            }
        }
    }
}
