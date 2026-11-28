pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

// Like Windows' Processes tab: apps (open windows, each with every process under them), then
// background processes (yours) and system processes (other users'), each grouped with its
// children; groups expand to their processes. CPU, memory, disk. Select one to end it
// (Delete), force it (Shift+Delete), pause or resume it.
Item {
    id: root

    required property var window

    property string sortKey: "cpu"
    property bool ascending: false
    property string filter
    property var expanded: []
    property string selected // a row's key: "app:<class>" or a pid
    property var appPids: ({}) // app key -> its windows' pids

    readonly property var selectedRow: {
        rowsRevision;
        for (let i = 0; i < rows.count; i++)
            if (rows.get(i).key === selected)
                return rows.get(i);
        return null;
    }
    property int rowsRevision

    // The columns after the name: which, in what order (right-click the titles), kept in
    // ~/.local/state/caelestia/taskmanager.json
    readonly property var columnDefs: ({
            status: {
                label: qsTr("Status"),
                width: 100
            },
            pid: {
                label: qsTr("PID"),
                width: 80
            },
            user: {
                label: qsTr("User"),
                width: 110
            },
            cpu: {
                label: qsTr("CPU"),
                width: 90,
                total: "cpu"
            },
            memory: {
                label: qsTr("Memory"),
                width: 110,
                total: "memory"
            },
            resident: {
                label: qsTr("Memory (all)"),
                width: 120
            },
            disk: {
                label: qsTr("Disk"),
                width: 110,
                total: "disk"
            },
            gpu: {
                label: qsTr("GPU"),
                width: 80,
                total: "gpu"
            },
            gpumem: {
                label: qsTr("GPU memory"),
                width: 135,
                total: "gpumem"
            },
            threads: {
                label: qsTr("Threads"),
                width: 80
            },
            nice: {
                label: qsTr("Priority"),
                width: 90
            },
            started: {
                label: qsTr("Running for"),
                width: 110
            },
            unit: {
                label: qsTr("Service"),
                width: 190
            },
            command: {
                label: qsTr("Command line"),
                width: 260
            }
        })
    readonly property var allColumns: ["status", "pid", "user", "cpu", "memory", "resident", "disk", "gpu", "gpumem", "threads", "nice", "started", "unit", "command"]
    readonly property var defaultColumns: ["status", "cpu", "memory", "disk", "gpu", "gpumem"]
    property var shownColumns: defaultColumns
    readonly property int fixedWidth: shownColumns.reduce((sum, k) => sum + (columnDefs[k]?.width ?? 0), 0)
    property bool columnMenuOpen
    property point columnMenuAt

    function setColumns(list: var): void {
        shownColumns = list;
        settings.setText(JSON.stringify({
            columns: list,
            sortKey: sortKey,
            ascending: ascending
        }));
    }

    function moveColumn(key: string, by: int): void {
        const list = [...shownColumns];
        const i = list.indexOf(key), j = i + by;
        if (i < 0 || j < 0 || j >= list.length)
            return;
        list.splice(i, 1);
        list.splice(j, 0, key);
        setColumns(list);
    }

    function niceLabel(n: int): string {
        return n >= 19 ? qsTr("Low") : n >= 10 ? qsTr("Lower") : n === 0 ? qsTr("Normal") : n <= -10 ? qsTr("High") : n < 0 ? qsTr("Higher") : String(n);
    }

    function cellText(r: var, key: string): string {
        switch (key) {
        case "status":
            return status(r);
        case "pid":
            return r.kind === "app" ? "" : r.pid > 0 ? String(r.pid) : "";
        case "user":
            return r.user;
        case "cpu":
            return root.window.percent(r.cpu);
        case "memory":
            return root.window.bytes(r.memory);
        case "resident":
            return root.window.bytes(r.resident);
        case "disk":
            return r.disk > 0 ? root.window.rate(r.disk) : "—";
        case "gpu":
            return r.gpu > 0 ? root.window.percent(r.gpu) : "—";
        case "gpumem":
            return r.gpuMemory > 0 ? root.window.bytes(r.gpuMemory) : "—";
        case "threads":
            return String(r.threads);
        case "nice":
            return niceLabel(r.nice);
        case "started":
            {
                const age = Math.max(0, SystemStats.uptime - r.started);
                const d = Math.floor(age / 86400), h = Math.floor(age % 86400 / 3600), m = Math.floor(age % 3600 / 60);
                return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
            }
        case "unit":
            return r.unit || "—";
        case "command":
            return r.command;
        }
        return "";
    }

    function cellHeat(r: var, key: string): real {
        return key === "cpu" ? r.cpu * 4 : key === "memory" ? r.memory / 2147483648 : key === "disk" ? r.disk / 52428800 : key === "gpu" ? r.gpu * 3 : key === "gpumem" ? r.gpuMemory / 2147483648 : 0;
    }

    FileView {
        id: settings

        path: `${Paths.state}/taskmanager.json`
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d.columns))
                    root.shownColumns = d.columns.filter(k => root.allColumns.includes(k));
                if (d.sortKey)
                    root.sortKey = d.sortKey;
                if (d.ascending !== undefined)
                    root.ascending = d.ascending;
                root.refresh();
            } catch (e) {}
        }
    }

    // systemd services' descriptions (unit -> description), the system's and this user's
    property var unitDescriptions: ({})
    property var entryCache: ({})

    function entryFor(name: string): var {
        if (!(name in entryCache)) {
            const e = DesktopEntries.heuristicLookup(name);
            // (only a confident match: same name or executable)
            const exec = (e?.command ?? [])[0]?.split("/").pop() ?? "";
            entryCache[name] = e && (exec === name || e.id?.toLowerCase().includes(name.toLowerCase())) ? e : null;
        }
        return entryCache[name];
    }

    // What a row is called, what's under its name, its icon (a themed one or a symbol)
    function describe(r: var): var {
        if (r.kind === "app")
            return {
                title: r.name,
                subtitle: r.command,
                icon: r.icon,
                glyph: "apps"
            };
        if (r.pid === 2 || r.name === "Kernel threads")
            return {
                title: qsTr("Kernel threads"),
                subtitle: qsTr("The kernel's own workers"),
                icon: "",
                glyph: "memory"
            };
        const entry = entryFor(r.name);
        const service = r.unit.endsWith(".service") ? r.unit : "";
        const desc = service ? (unitDescriptions[service] ?? "") : "";
        const title = entry?.name || desc || r.name;
        const shells = ["bash", "fish", "zsh", "sh", "dash", "nu"];
        const glyph = shells.includes(r.name) ? "terminal" : service ? "settings" : r.user === "root" ? "shield" : "widgets";
        const bits = [];
        if (title !== r.name)
            bits.push(r.name);
        if (service && service !== `${r.name}.service`)
            bits.push(service);
        else if (title === r.name && r.command && r.command !== r.name)
            bits.push(r.command);
        if (r.user && r.user !== Quickshell.env("USER"))
            bits.push(r.user);
        return {
            title: title,
            subtitle: bits.join(" · "),
            icon: entry?.icon ? Quickshell.iconPath(entry.icon, true) : "",
            glyph: glyph
        };
    }

    function status(r: var): string {
        if (r.kind === "section")
            return "";
        if (r.procState === "T" || r.procState === "t")
            return qsTr("Paused");
        if (r.procState === "Z")
            return qsTr("Zombie");
        if (r.procState === "D")
            return qsTr("Waiting (disk)");
        return r.cpu > 0.001 ? qsTr("Running") : qsTr("Idle");
    }

    function focusSearch(): void {
        search.forceActiveFocus();
    }

    // The apps: windows grouped by app
    function apps(): var {
        const byClass = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.pid || o.pid <= 0)
                continue;
            const key = o.class || o.initialClass || o.title || String(o.pid);
            if (!byClass[key])
                byClass[key] = {
                    key: key,
                    title: o.title ?? "",
                    pids: []
                };
            if (!byClass[key].pids.includes(o.pid))
                byClass[key].pids.push(o.pid);
        }
        const list = [];
        const pids = {};
        for (const app of Object.values(byClass)) {
            const entry = DesktopEntries.heuristicLookup(app.key);
            app.name = entry?.name || app.key;
            app.icon = entry?.icon ? Quickshell.iconPath(entry.icon, "application-x-executable") : Icons.getAppIcon(app.key, "application-x-executable");
            pids[`app:${app.key}`] = app.pids;
            list.push(app);
        }
        appPids = pids;
        return list;
    }

    function refresh(): void {
        const items = Processes.tree(apps(), expanded, filter, sortKey, ascending);
        // (in place, so the list keeps its scroll position and rows)
        for (let i = 0; i < items.length; i++) {
            if (i < rows.count)
                rows.set(i, items[i]);
            else
                rows.append(items[i]);
        }
        if (rows.count > items.length)
            rows.remove(items.length, rows.count - items.length);
        rowsRevision++;
    }

    // The right-click menu and the details panel
    property point menuAt
    property bool menuOpen
    property int detailsPid: -1

    function openMenu(at: point): void {
        menuAt = at;
        menuOpen = true;
    }

    function priority(pid: int, nice: int): void {
        // (lowering it is allowed; raising it asks for the password)
        if (!Processes.setPriority(pid, nice))
            Quickshell.execDetached(["pkexec", "renice", "-n", String(nice), "-p", String(pid)]);
    }

    function switchTo(key: string): void {
        const pid = (appPids[key] ?? [])[0];
        if (!pid)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "pid:${pid}" })` : `focuswindow pid:${pid}`);
        root.window.closeRequested();
    }

    function toggle(key: string): void {
        expanded = expanded.includes(key) ? expanded.filter(k => k !== key) : [...expanded, key];
        refresh();
    }

    function sortBy(key: string): void {
        if (sortKey === key)
            ascending = !ascending;
        else {
            sortKey = key;
            ascending = ["name", "user", "pid", "unit", "command"].includes(key);
        }
        setColumns(shownColumns);
        refresh();
    }

    function end(force: bool): void {
        const r = selectedRow;
        if (!r)
            return;
        const sig = force ? "kill" : "term";
        if (r.kind === "app")
            for (const pid of appPids[r.key] ?? [])
                Processes.signalTree(pid, sig);
        else if (r.kind === "group")
            Processes.signalTree(r.pid, sig);
        else
            Processes.signal(r.pid, sig);
        refresh();
    }

    ListModel {
        id: rows
    }

    Component.onCompleted: refresh()

    Process {
        id: systemUnits

        command: ["systemctl", "list-units", "--all", "--type=service", "--output=json", "--no-pager"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.addDescriptions(text)
        }
    }

    Process {
        id: userUnits

        command: ["systemctl", "--user", "list-units", "--all", "--type=service", "--output=json", "--no-pager"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.addDescriptions(text)
        }
    }

    function addDescriptions(text: string): void {
        try {
            const map = Object.assign({}, unitDescriptions);
            for (const u of JSON.parse(text))
                map[u.unit] = u.description;
            unitDescriptions = map;
        } catch (e) {}
    }

    ServiceRef {
        service: Processes
    }

    Connections {
        function onUpdated(): void {
            root.refresh();
        }

        target: Processes
    }

    // (the windows' pids come from Hyprland's IPC: refreshed now and then)
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: Hyprland.refreshToplevels()
    }

    Keys.onDeletePressed: event => root.end(event.modifiers & Qt.ShiftModifier)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledTextField {
                id: search

                Layout.preferredWidth: 340
                placeholderText: qsTr("Search processes")
                leadingIcon: "search"
                onTextChanged: {
                    root.filter = text;
                    root.refresh();
                }
                Keys.onEscapePressed: event => {
                    if (text !== "") {
                        text = "";
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                Layout.maximumWidth: 300
                elide: Text.ElideRight
                text: qsTr("%1 processes · %2 threads").arg(Processes.total).arg(Processes.threads)
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // Column titles (click to sort, right-click to choose and move them), with the
        // machine's totals above them like Windows'
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium + 8
            implicitHeight: 44

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    root.columnMenuAt = mapToItem(root, mouse.x, mouse.y);
                    root.columnMenuOpen = true;
                }
            }

            Row {
                anchors.fill: parent

                HeaderCell {
                    key: "name"
                    label: qsTr("Name")
                    width: parent.width - root.fixedWidth
                    alignLeft: true
                }

                Repeater {
                    model: root.shownColumns

                    HeaderCell {
                        required property string modelData

                        key: modelData
                        label: root.columnDefs[modelData]?.label ?? modelData
                        width: root.columnDefs[modelData]?.width ?? 80
                        total: root.columnDefs[modelData]?.total ?? ""
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: rows

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: Item {
                id: rowItem

                required property var model

                // (the row's values; "state" would clash with Item's own)
                readonly property string kind: model.kind
                readonly property string key: model.key
                readonly property string name: model.name
                readonly property string icon: model.icon
                readonly property int depth: model.depth
                readonly property int pid: model.pid
                readonly property string user: model.user
                readonly property string unit: model.unit
                readonly property string command: model.command
                readonly property string procState: model.state
                readonly property real cpu: model.cpu
                readonly property real memory: model.memory
                readonly property real disk: model.disk
                readonly property int count: model.count
                readonly property bool expanded: model.expanded
                readonly property real resident: model.resident
                readonly property real threads: model.threads
                readonly property real nice: model.nice
                readonly property real started: model.started
                readonly property real gpu: model.gpu
                readonly property real gpuMemory: model.gpuMemory

                readonly property bool isSection: kind === "section"
                readonly property bool isGroup: kind === "app" || kind === "group"
                readonly property var info: isSection ? ({}) : root.describe(rowItem)

                width: list.width - 8
                implicitHeight: isSection ? 40 : depth > 0 ? 40 : 48

                // A part's title, with its count
                Row {
                    visible: rowItem.isSection
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.padding.small
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: rowItem.name
                        font: Tokens.font.title.small
                        color: Colours.palette.m3primary
                    }

                    StyledRect {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: countText.implicitWidth + 12
                        implicitHeight: countText.implicitHeight + 4
                        radius: height / 2
                        color: Colours.palette.m3secondaryContainer

                        StyledText {
                            id: countText

                            anchors.centerIn: parent
                            text: rowItem.count
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }

                StyledRect {
                    visible: !rowItem.isSection
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    radius: Tokens.rounding.medium
                    color: root.selected === rowItem.key ? Colours.palette.m3secondaryContainer : rowItem.depth > 0 ? Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.5) : "transparent"

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            root.selected = rowItem.key;
                            root.forceActiveFocus();
                            if (mouse.button === Qt.RightButton)
                                root.openMenu(mapToItem(root, mouse.x, mouse.y));
                        }
                        onDoubleClicked: if (rowItem.isGroup)
                            root.toggle(rowItem.key)
                    }
                }

                Row {
                    visible: !rowItem.isSection
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small
                    anchors.rightMargin: Tokens.padding.medium

                    Item {
                        width: parent.width - root.fixedWidth
                        height: parent.height

                        // Expand / collapse
                        Item {
                            id: chevron

                            x: rowItem.depth * 28
                            width: 28
                            height: parent.height

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: rowItem.isGroup
                                text: "chevron_right"
                                rotation: rowItem.expanded ? 90 : 0
                                color: Colours.palette.m3onSurfaceVariant

                                Behavior on rotation {
                                    Anim {}
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: rowItem.isGroup
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggle(rowItem.key)
                            }
                        }

                        // Its icon: the app's own, else a symbol for what it is
                        Item {
                            id: iconBox

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: chevron.right
                            width: rowItem.depth > 0 ? 24 : 30
                            height: width

                            ThemedIcon {
                                anchors.fill: parent
                                visible: rowItem.info.icon !== ""
                                asynchronous: true
                                source: rowItem.info.icon ?? ""
                            }

                            StyledRect {
                                anchors.fill: parent
                                visible: !rowItem.info.icon
                                radius: Tokens.rounding.small
                                color: Colours.palette.m3surfaceContainerHighest

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: rowItem.info.glyph ?? "widgets"
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: iconBox.right
                            anchors.leftMargin: Tokens.spacing.medium
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.spacing.small

                            Row {
                                width: parent.width
                                spacing: Tokens.spacing.small

                                StyledText {
                                    id: titleText

                                    width: Math.min(implicitWidth, parent.width - (countLabel.visible ? countLabel.implicitWidth + 8 : 0))
                                    elide: Text.ElideRight
                                    text: rowItem.info.title ?? rowItem.name
                                    font: rowItem.depth === 0 ? Tokens.font.body.medium : Tokens.font.body.small
                                    color: Colours.palette.m3onSurface
                                }

                                StyledText {
                                    id: countLabel

                                    anchors.verticalCenter: titleText.verticalCenter
                                    visible: rowItem.isGroup
                                    text: `(${rowItem.count})`
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: text !== ""
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                text: rowItem.info.subtitle ?? ""
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    Repeater {
                        model: root.shownColumns

                        Cell {
                            required property string modelData

                            width: root.columnDefs[modelData]?.width ?? 80
                            text: {
                                rowItem.cpu; // (each reading)
                                return root.cellText(rowItem, modelData);
                            }
                            heat: root.cellHeat(rowItem, modelData)
                            dim: ["status", "pid", "user", "unit", "command", "nice", "started", "threads"].includes(modelData)
                            alignLeft: modelData === "command" || modelData === "unit"
                        }
                    }
                }
            }
        }

        // The selection and what can be done to it
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: bar.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: bar

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                anchors.leftMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    text: {
                        const r = root.selectedRow;
                        if (!r)
                            return qsTr("Select an app or process");
                        if (r.kind === "app" || r.kind === "group")
                            return qsTr("%1 — %2 processes, %3").arg(r.name).arg(r.count).arg(root.window.bytes(r.memory));
                        const i = Processes.info(r.pid);
                        return i.pid ? `${i.name} (${i.pid}) — ${i.command}` : r.name;
                    }
                }

                TabButton {
                    visible: root.selectedRow !== null && root.selectedRow.kind === "proc"
                    label: root.selectedRow?.state === "T" ? qsTr("Resume") : qsTr("Pause")
                    icon: root.selectedRow?.state === "T" ? "play_arrow" : "pause"
                    onClicked: {
                        Processes.signal(root.selectedRow.pid, root.selectedRow.state === "T" ? "cont" : "stop");
                        root.refresh();
                    }
                }

                TabButton {
                    usable: root.selectedRow !== null
                    label: qsTr("Force stop")
                    icon: "dangerous"
                    danger: true
                    onClicked: root.end(true)
                }

                TabButton {
                    usable: root.selectedRow !== null
                    selected: true
                    label: root.selectedRow?.kind === "app" ? qsTr("End task") : qsTr("End process")
                    icon: "close"
                    onClicked: root.end(false)
                }
            }
        }
    }

    // Right-click menu
    MouseArea {
        anchors.fill: parent
        visible: root.menuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.menuOpen = false
    }

    StyledRect {
        id: menu

        readonly property var row: root.selectedRow
        readonly property bool isApp: row?.kind === "app"
        readonly property bool isGroup: row?.kind === "group"
        readonly property bool isProc: row?.kind === "proc"
        readonly property var info: root.menuOpen && row && !isApp ? Processes.info(row.pid) : ({})

        visible: root.menuOpen && row !== null
        x: Math.min(root.menuAt.x, root.width - width - 8)
        y: Math.min(root.menuAt.y, root.height - height - 8)
        width: 330
        implicitHeight: menuColumn.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.medium
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

        Column {
            id: menuColumn

            anchors.fill: parent
            anchors.margins: Tokens.padding.small

            MenuEntry {
                visible: menu.isApp
                icon: "open_in_new"
                label: qsTr("Switch to")
                onClicked: root.switchTo(menu.row.key)
            }

            MenuEntry {
                visible: menu.isApp || menu.isGroup
                icon: menu.row?.expanded ? "unfold_less" : "unfold_more"
                label: menu.row?.expanded ? qsTr("Collapse") : qsTr("Expand")
                onClicked: root.toggle(menu.row.key)
            }

            MenuEntry {
                icon: "close"
                label: menu.isApp ? qsTr("End task") : menu.isGroup ? qsTr("End process tree") : qsTr("End process")
                onClicked: root.end(false)
            }

            MenuEntry {
                visible: menu.isProc
                icon: "account_tree"
                label: qsTr("End process tree")
                onClicked: Processes.signalTree(menu.row.pid, "term")
            }

            MenuEntry {
                icon: "dangerous"
                label: qsTr("Force stop")
                danger: true
                onClicked: root.end(true)
            }

            MenuEntry {
                visible: menu.isProc
                icon: menu.row?.state === "T" ? "play_arrow" : "pause"
                label: menu.row?.state === "T" ? qsTr("Resume") : qsTr("Pause")
                onClicked: Processes.signal(menu.row.pid, menu.row.state === "T" ? "cont" : "stop")
            }

            // Priority, like Windows' "Set priority"
            Item {
                visible: !menu.isApp
                width: parent.width
                height: priorityRow.implicitHeight + Tokens.padding.small * 2

                Column {
                    id: priorityRow

                    anchors.verticalCenter: parent.verticalCenter
                    x: Tokens.padding.medium
                    width: parent.width - Tokens.padding.medium * 2
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Priority")
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Flow {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: [[qsTr("Low"), 19], [qsTr("Lower"), 10], [qsTr("Normal"), 0], [qsTr("Higher"), -5], [qsTr("High"), -10]]

                            StyledRect {
                                required property var modelData
                                readonly property bool current: (menu.info.nice ?? 0) === modelData[1]

                                implicitWidth: chip.implicitWidth + 12
                                implicitHeight: chip.implicitHeight + 8
                                radius: height / 2
                                color: current ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                                StyledText {
                                    id: chip

                                    anchors.centerIn: parent
                                    text: parent.modelData[0]
                                    font: Tokens.font.label.small
                                    color: parent.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                }

                                StateLayer {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    onClicked: {
                                        root.priority(menu.row.pid, parent.modelData[1]);
                                        root.menuOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MenuEntry {
                visible: !menu.isApp && (menu.info.exe ?? "") !== ""
                icon: "folder_open"
                label: qsTr("Open file location")
                onClicked: Quickshell.execDetached(["xdg-open", menu.info.exe.substring(0, menu.info.exe.lastIndexOf("/")) || "/"])
            }

            MenuEntry {
                visible: !menu.isApp
                icon: "content_copy"
                label: qsTr("Copy command line")
                onClicked: Quickshell.clipboardText = menu.info.command ?? ""
            }

            MenuEntry {
                visible: !menu.isApp
                icon: "info"
                label: qsTr("Properties")
                onClicked: root.detailsPid = menu.row.pid
            }
        }
    }

    // A process's details (Properties)
    MouseArea {
        anchors.fill: parent
        visible: root.detailsPid > 0
        onClicked: root.detailsPid = -1
    }

    StyledRect {
        id: details

        readonly property var info: {
            Processes.total; // (each reading)
            return root.detailsPid > 0 ? Processes.info(root.detailsPid) : ({});
        }

        visible: root.detailsPid > 0
        anchors.centerIn: parent
        width: Math.min(640, parent.width - 48)
        implicitHeight: detailsColumn.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

        // (clicks inside stay inside)
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: detailsColumn

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: details.info.pid ? `${details.info.name}` : qsTr("This process has ended")
                    font: Tokens.font.title.large
                    color: Colours.palette.m3onSurface
                }

                TabButton {
                    icon: "close"
                    onClicked: root.detailsPid = -1
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: details.info.pid !== undefined
                columns: 2
                columnSpacing: Tokens.spacing.large
                rowSpacing: Tokens.spacing.small

                Repeater {
                    model: {
                        const i = details.info;
                        if (!i.pid)
                            return [];
                        const age = Math.max(0, (i.uptime ?? 0) - (i.started ?? 0));
                        const h = Math.floor(age / 3600), m = Math.floor(age % 3600 / 60);
                        const states = {
                            R: qsTr("Running"),
                            S: qsTr("Sleeping"),
                            D: qsTr("Waiting for disk"),
                            T: qsTr("Paused"),
                            Z: qsTr("Zombie"),
                            I: qsTr("Idle")
                        };
                        return [[qsTr("Process ID"), `${i.pid} (parent ${i.ppid})`], [qsTr("User"), i.user], [qsTr("State"), states[i.state] ?? i.state], [qsTr("Running for"), h > 0 ? `${h} h ${m} min` : `${m} min`], [qsTr("CPU"), root.window.percent(i.cpu)], [qsTr("Memory (private)"), root.window.bytes(i.memory)], [qsTr("Memory (all resident)"), root.window.bytes(i.resident)], [qsTr("Disk"), `${root.window.rate(i.diskRead)} read, ${root.window.rate(i.diskWrite)} written`], [qsTr("Threads"), i.threads], [qsTr("Priority (nice)"), i.nice], [qsTr("Service"), i.unit || "—"], [qsTr("Program"), i.exe || "—"], [qsTr("Working folder"), i.cwd || "—"], [qsTr("Command line"), i.command || "—"]];
                    }

                    Item {
                        id: pair

                        required property var modelData
                        required property int index

                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        implicitHeight: Math.max(k.implicitHeight, v.implicitHeight)

                        StyledText {
                            id: k

                            width: 170
                            text: pair.modelData[0]
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            id: v

                            anchors.left: k.right
                            anchors.right: parent.right
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            text: String(pair.modelData[1])
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }
    }

    component MenuEntry: StyledRect {
        id: entry

        property string icon
        property string label
        property bool danger

        signal clicked

        width: parent?.width ?? 0
        implicitHeight: visible ? 36 : 0
        radius: Tokens.rounding.small
        color: "transparent"

        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: {
                root.menuOpen = false;
                entry.clicked();
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.icon
                color: entry.danger ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: entry.width - Tokens.padding.medium * 2 - 40
                elide: Text.ElideRight
                text: entry.label
                font: Tokens.font.body.small
                color: entry.danger ? Colours.palette.m3error : Colours.palette.m3onSurface
            }
        }
    }

    // Column chooser: show/hide each column, move it left or right
    MouseArea {
        anchors.fill: parent
        visible: root.columnMenuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.columnMenuOpen = false
    }

    StyledRect {
        visible: root.columnMenuOpen
        x: Math.min(root.columnMenuAt.x, root.width - width - 8)
        y: Math.min(root.columnMenuAt.y, root.height - height - 8)
        width: 280
        implicitHeight: columnList.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.medium
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: columnList

            anchors.fill: parent
            anchors.margins: Tokens.padding.small

            StyledText {
                leftPadding: Tokens.padding.medium
                bottomPadding: Tokens.padding.small
                text: qsTr("Columns")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            // Shown ones in their order, then the hidden ones
            Repeater {
                model: [...root.shownColumns, ...root.allColumns.filter(k => !root.shownColumns.includes(k))]

                Item {
                    id: colEntry

                    required property string modelData
                    readonly property bool shown: root.shownColumns.includes(modelData)
                    readonly property int position: root.shownColumns.indexOf(modelData)

                    width: parent.width
                    height: 34

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        onClicked: root.setColumns(colEntry.shown ? root.shownColumns.filter(k => k !== colEntry.modelData) : [...root.shownColumns, colEntry.modelData])
                    }

                    MaterialIcon {
                        id: check

                        anchors.verticalCenter: parent.verticalCenter
                        x: Tokens.padding.medium
                        text: colEntry.shown ? "check_box" : "check_box_outline_blank"
                        fill: colEntry.shown ? 1 : 0
                        color: colEntry.shown ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: check.right
                        anchors.leftMargin: Tokens.spacing.medium
                        text: root.columnDefs[colEntry.modelData].label
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurface
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.padding.small
                        visible: colEntry.shown

                        TabButton {
                            icon: "arrow_back"
                            implicitHeight: 28
                            usable: colEntry.position > 0
                            onClicked: root.moveColumn(colEntry.modelData, -1)
                        }

                        TabButton {
                            icon: "arrow_forward"
                            implicitHeight: 28
                            usable: colEntry.position < root.shownColumns.length - 1
                            onClicked: root.moveColumn(colEntry.modelData, 1)
                        }
                    }
                }
            }

            MenuEntry {
                icon: "restart_alt"
                label: qsTr("Reset columns")
                onClicked: root.setColumns(root.defaultColumns)
            }
        }
    }

    // A column title: the total above (CPU, memory, disk), the name; click to sort
    component HeaderCell: Item {
        id: header

        property string key
        property string label
        property string total
        property bool alignLeft
        readonly property bool sorted: root.sortKey === key
        readonly property bool sortable: key !== "status"

        height: parent.height

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: header.alignLeft ? 36 : Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small

            StyledText {
                width: parent.width
                horizontalAlignment: header.alignLeft ? Text.AlignLeft : Text.AlignRight
                visible: header.total !== ""
                text: {
                    if (header.total === "cpu")
                        return root.window.percent(SystemStats.cpu);
                    if (header.total === "memory")
                        return SystemStats.memTotal > 0 ? root.window.percent(SystemStats.memUsed / SystemStats.memTotal) : "";
                    if (header.total === "disk")
                        return root.window.percent(Math.max(0, ...SystemStats.disks.map(d => d.busy)));
                    if (header.total === "gpu")
                        return root.window.percent(Gpu.percentage);
                    if (header.total === "gpumem")
                        return Gpu.memoryTotal > 0 ? root.window.percent(Gpu.memoryUsed / Gpu.memoryTotal) : "";
                    return "";
                }
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            StyledText {
                width: parent.width
                horizontalAlignment: header.alignLeft ? Text.AlignLeft : Text.AlignRight
                elide: Text.ElideRight
                text: header.label + (header.sorted ? (root.ascending ? " ▲" : " ▼") : "")
                font: Tokens.font.label.medium
                color: header.sorted ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: header.sortable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sortBy(header.key)
        }
    }

    // A right-aligned number, its background warmer the busier it is (like Windows')
    component Cell: Item {
        property alias text: cellText.text
        property real heat
        property bool dim
        property bool alignLeft

        height: parent.height

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 4
            color: Colours.palette.m3primary
            opacity: Math.min(0.35, Math.max(0, parent.heat) * 0.35)
        }

        StyledText {
            id: cellText

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            horizontalAlignment: parent.alignLeft ? Text.AlignLeft : Text.AlignRight
            elide: Text.ElideRight
            maximumLineCount: 1
            font: Tokens.font.body.small
            color: parent.dim ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        }
    }
}
