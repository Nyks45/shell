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
    // Defaults by file type (xdg-mime): first type -> desktop entry id
    property var mimeDefaults: ({})
    readonly property var mimeGroups: ({
            images: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/svg+xml", "image/tiff", "image/avif", "image/heic", "image/x-icon"],
            video: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/ogg", "video/x-flv"],
            music: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/wav", "audio/mp4", "audio/aac", "audio/opus", "audio/x-vorbis+ogg"],
            pdf: ["application/pdf"],
            archives: ["application/zip", "application/x-tar", "application/x-7z-compressed", "application/vnd.rar", "application/x-rar", "application/gzip", "application/x-compressed-tar", "application/x-xz-compressed-tar", "application/zstd", "application/x-bzip2"],
            email: ["x-scheme-handler/mailto"]
        })
    readonly property list<string> textTypes: ["text/plain", "text/markdown", "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/x-c++hdr", "text/x-python", "text/x-shellscript", "application/x-shellscript", "application/json", "application/xml", "application/toml", "text/x-lua", "application/x-yaml", "text/x-log"]

    // A desktop entry's command for the config (no %u-style placeholders)
    function commandOf(app: DesktopEntry): string {
        return app.command.filter(a => !/^%[a-zA-Z]$/.test(a)).join(" ");
    }

    function nameOf(id: string): string {
        return DesktopEntries.byId(id.replace(/\.desktop$/, ""))?.name ?? id.replace(/\.desktop$/, "");
    }

    function friendlyCommandName(cmd: var): string {
        if (!cmd || cmd.length === 0)
            return Tr.tr("Not set");
        const curStr = cmd.join(" ");
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
            status: root.friendlyCommandName(GlobalConfig.general.apps.terminal)
            currentCommand: GlobalConfig.general.apps.terminal
            onSelected: app => GlobalConfig.general.apps.terminal = app.command
        }

        DefaultRow {
            icon: "volume_up"
            label: Tr.trCtx("Sound mixer", "default app category")
            category: "Audio"
            status: root.friendlyCommandName(GlobalConfig.general.apps.audio)
            currentCommand: GlobalConfig.general.apps.audio
            onSelected: app => GlobalConfig.general.apps.audio = app.command
        }

        DefaultRow {
            icon: "play_circle"
            label: Tr.trCtx("Media playback", "default app category")
            category: "Player"
            status: root.friendlyCommandName(GlobalConfig.general.apps.playback)
            currentCommand: GlobalConfig.general.apps.playback
            onSelected: app => GlobalConfig.general.apps.playback = app.command
        }

        DefaultRow {
            icon: "folder"
            label: Tr.trCtx("File manager", "default app category")
            category: "FileManager"
            status: root.friendlyCommandName(GlobalConfig.general.apps.explorer)
            currentCommand: GlobalConfig.general.apps.explorer
            onSelected: app => GlobalConfig.general.apps.explorer = app.command
        }

        DefaultRow {
            icon: "language"
            label: Tr.trCtx("Web browser", "default app category")
            category: "WebBrowser"
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
            category: "Graphics"
        }

        DefaultRow {
            icon: "movie"
            label: Tr.trCtx("Videos", "default app category")
            group: "video"
            category: "Video"
        }

        DefaultRow {
            icon: "music_note"
            label: Tr.trCtx("Music", "default app category")
            group: "music"
            category: "Audio"
        }

        DefaultRow {
            icon: "picture_as_pdf"
            label: Tr.trCtx("PDF documents", "default app category")
            group: "pdf"
            category: "Office"
        }

        DefaultRow {
            icon: "folder_zip"
            label: Tr.trCtx("Archives", "default app category")
            group: "archives"
            category: "Archiving"
        }

        DefaultRow {
            icon: "mail"
            label: Tr.trCtx("Email", "default app category")
            group: "email"
            category: "Email"
        }

        Process {
            id: mimeProc

            running: true
            command: ["sh", "-c", Object.entries(root.mimeGroups).map(([g, types]) => `echo "${g}=$(xdg-mime query default ${types[0]})"`).join("; ")]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = {};
                    for (const line of text.split("\n")) {
                        const i = line.indexOf("=");
                        if (i > 0)
                            out[line.slice(0, i)] = line.slice(i + 1).trim();
                    }
                    root.mimeDefaults = out;
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

        property var currentCommand: []
        property string currentId: group ? (root.mimeDefaults[group] ?? "") : ""
        property string query

        readonly property var allApps: {
            if (!popup.active)
                return [];
            const all = [...DesktopEntries.applications.values];
            const ofKind = category ? all.filter(a => a.categories.includes(category)) : [];
            const apps = ofKind.length > 0 ? ofKind : all;
            const favourited = new Set(apps.filter(a => Strings.testRegexList(GlobalConfig.launcher.favouriteApps, a.id)));
            return apps.sort((a, b) => (favourited.has(b) - favourited.has(a)) || a.name.localeCompare(b.name));
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
        readonly property real listH: filteredApps.length > 0 ? Math.min(240, filteredApps.length * rowH + Math.max(0, filteredApps.length - 1) * 2) : 48

        function isCurrent(app: DesktopEntry): bool {
            if (currentId) {
                const target = currentId.replace(/\.desktop$/, "");
                if (app.id.replace(/\.desktop$/, "") === target)
                    return true;
            }
            if (currentCommand && currentCommand.length > 0) {
                const curStr = currentCommand.join(" ");
                const appCmd = root.commandOf(app);
                if (appCmd === curStr || app.command.join(" ") === curStr)
                    return true;
                const curBin = String(currentCommand[0] ?? "").split("/").pop();
                const appBin = String(app.command[0] ?? "").split("/").pop();
                if (curBin && appBin && curBin === appBin)
                    return true;
            }
            return false;
        }

        signal selected(app: DesktopEntry)

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
                if (!row.popup.active)
                    row.query = "";
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
            : Math.round(CUtils.clamp(allApps.reduce((m, a) => Math.max(m, (a.name ?? "").length), 0) * itemMetrics.averageCharacterWidth + 20 + Tokens.spacing.small + Tokens.padding.medium * 2 + 28, 176, 260))
        popupHeight: (showSearch ? (searchH + Tokens.spacing.small) : 0) + listH
        maxPopupHeight: showSearch ? 280 : 256

        FontMetrics {
            id: itemMetrics

            font: Tokens.font.body.small
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

                            required property DesktopEntry modelData
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
                                    visible: Strings.testRegexList(GlobalConfig.launcher.favouriteApps, appItem.modelData.id)
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
                        text: Tr.tr("No apps match")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                    }
                }
            }
        }
    }
}
