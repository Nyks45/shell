pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Apps (open windows, each with all its processes) and every process: CPU, memory, disk.
// Select one and end it (Delete), force it (Shift+Delete), or pause and resume it.
Item {
    id: root

    required property var window

    property int selectedPid: -1
    property string selectedApp: ""
    property var apps: []

    function focusSearch(): void {
        search.forceActiveFocus();
    }

    // Windows grouped by app, with their processes' totals
    function updateApps(): void {
        const byClass = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.pid || o.pid <= 0)
                continue;
            const key = o.class || o.initialClass || o.title;
            if (!byClass[key])
                byClass[key] = {
                    cls: key,
                    title: o.title,
                    pids: [],
                    windows: 0
                };
            if (!byClass[key].pids.includes(o.pid))
                byClass[key].pids.push(o.pid);
            byClass[key].windows++;
        }
        const list = [];
        for (const app of Object.values(byClass)) {
            const g = Processes.group(app.pids);
            const entry = DesktopEntries.heuristicLookup(app.cls);
            list.push(Object.assign(app, g, {
                name: entry?.name || app.cls,
                icon: entry?.icon ? Quickshell.iconPath(entry.icon, "application-x-executable") : Icons.getAppIcon(app.cls, "application-x-executable")
            }));
        }
        list.sort((a, b) => b.cpu - a.cpu || b.memory - a.memory);
        apps = list;
    }

    function end(force: bool): void {
        if (selectedApp !== "") {
            const app = apps.find(a => a.cls === selectedApp);
            for (const pid of app?.pids ?? [])
                Processes.signalTree(pid, force ? "kill" : "term");
        } else if (selectedPid > 0) {
            Processes.signal(selectedPid, force ? "kill" : "term");
        }
    }

    readonly property var selectedInfo: {
        Processes.total; // (re-read each tick)
        return selectedPid > 0 ? Processes.info(selectedPid) : ({});
    }

    ServiceRef {
        service: Processes
    }

    Connections {
        function onUpdated(): void {
            root.updateApps();
        }

        target: Processes
    }

    // (window list: the pids come from Hyprland's IPC, refreshed every few seconds)
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
                onTextChanged: Processes.model.filter = text
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
                text: qsTr("%1 apps · %2 processes · %3 threads").arg(root.apps.length).arg(Processes.total).arg(Processes.threads)
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // Column titles (click to sort)
        Row {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium

            Repeater {
                model: [
                    {
                        key: "name",
                        label: qsTr("Name"),
                        width: 0
                    },
                    {
                        key: "pid",
                        label: qsTr("PID"),
                        width: 80
                    },
                    {
                        key: "user",
                        label: qsTr("User"),
                        width: 110
                    },
                    {
                        key: "cpu",
                        label: qsTr("CPU"),
                        width: 90
                    },
                    {
                        key: "memory",
                        label: qsTr("Memory"),
                        width: 110
                    },
                    {
                        key: "disk",
                        label: qsTr("Disk"),
                        width: 120
                    }
                ]

                Item {
                    required property var modelData

                    width: modelData.width > 0 ? modelData.width : parent.width - 510
                    height: 28

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.modelData.width > 0 ? parent.right : undefined
                        anchors.rightMargin: Tokens.padding.small
                        text: parent.modelData.label + (Processes.model.sortKey === parent.modelData.key ? (Processes.model.sortAscending ? "  ▲" : "  ▼") : "")
                        font: Tokens.font.label.medium
                        color: Processes.model.sortKey === parent.modelData.key ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const key = parent.modelData.key;
                            if (Processes.model.sortKey === key)
                                Processes.model.sortAscending = !Processes.model.sortAscending;
                            else {
                                Processes.model.sortKey = key;
                                Processes.model.sortAscending = key === "name" || key === "user" || key === "pid";
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            // Apps first, like Mission Center (hidden while searching)
            header: Column {
                width: list.width
                visible: search.text === ""
                height: visible ? implicitHeight : 0

                SectionTitle {
                    text: qsTr("Apps")
                }

                Repeater {
                    model: root.apps

                    Row_ {
                        required property var modelData

                        width: list.width
                        selected: root.selectedApp === modelData.cls
                        iconSource: modelData.icon
                        name: modelData.name
                        detail: modelData.windows > 1 ? qsTr("%1 windows · %2 processes").arg(modelData.windows).arg(modelData.processes) : qsTr("%1 processes").arg(modelData.processes)
                        user: ""
                        cpu: modelData.cpu
                        memory: modelData.memory
                        disk: modelData.diskRead + modelData.diskWrite
                        onPicked: {
                            root.selectedApp = modelData.cls;
                            root.selectedPid = -1;
                            root.forceActiveFocus();
                        }
                    }
                }

                SectionTitle {
                    text: qsTr("Processes")
                }
            }

            model: Processes.model

            delegate: Row_ {
                required property var model

                width: list.width
                selected: root.selectedPid === model.pid
                name: model.name
                detail: model.state === "T" ? qsTr("Paused") : model.state === "Z" ? qsTr("Zombie") : ""
                pidText: model.pid
                user: model.user
                cpu: model.cpu
                memory: model.memory
                disk: model.diskRead + model.diskWrite
                onPicked: {
                    root.selectedPid = model.pid;
                    root.selectedApp = "";
                    root.forceActiveFocus();
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
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    text: {
                        if (root.selectedApp !== "") {
                            const app = root.apps.find(a => a.cls === root.selectedApp);
                            return app ? qsTr("%1 — %2 processes, %3").arg(app.name).arg(app.processes).arg(root.window.bytes(app.memory)) : "";
                        }
                        const i = root.selectedInfo;
                        return i.pid ? `${i.name} (${i.pid}) — ${i.command}` : qsTr("Select an app or process");
                    }
                }

                TabButton {
                    visible: root.selectedApp === "" && root.selectedPid > 0
                    label: root.selectedInfo.state === "T" ? qsTr("Resume") : qsTr("Pause")
                    icon: root.selectedInfo.state === "T" ? "play_arrow" : "pause"
                    onClicked: Processes.signal(root.selectedPid, root.selectedInfo.state === "T" ? "cont" : "stop")
                }

                TabButton {
                    usable: root.selectedApp !== "" || root.selectedPid > 0
                    label: qsTr("Force stop")
                    icon: "dangerous"
                    danger: true
                    onClicked: root.end(true)
                }

                TabButton {
                    usable: root.selectedApp !== "" || root.selectedPid > 0
                    selected: true
                    label: root.selectedApp !== "" ? qsTr("End task") : qsTr("End process")
                    icon: "close"
                    onClicked: root.end(false)
                }
            }
        }
    }

    component SectionTitle: StyledText {
        leftPadding: Tokens.padding.medium
        topPadding: Tokens.padding.small
        bottomPadding: Tokens.padding.extraSmall
        font: Tokens.font.title.small
        color: Colours.palette.m3primary
    }

    // One app or process: name (icon), PID, user, CPU, memory, disk
    component Row_: Item {
        id: rowItem

        property bool selected
        property string iconSource
        property string name
        property string detail
        property var pidText: ""
        property string user
        property real cpu
        property real memory
        property real disk

        signal picked

        implicitHeight: 36

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.small
            color: rowItem.selected ? Colours.palette.m3secondaryContainer : "transparent"

            StateLayer {
                anchors.fill: parent
                radius: parent.radius
                onClicked: rowItem.picked()
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium

            Item {
                width: parent.width - 510
                height: parent.height

                IconImage {
                    id: icon

                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.iconSource !== ""
                    implicitSize: 22
                    asynchronous: true
                    source: rowItem.iconSource
                }

                StyledText {
                    id: nameText

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: icon.visible ? icon.right : parent.left
                    anchors.leftMargin: icon.visible ? Tokens.spacing.small : 0
                    width: Math.min(implicitWidth, parent.width - x - (detailText.visible ? detailText.implicitWidth + 12 : 0))
                    elide: Text.ElideRight
                    text: rowItem.name
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    id: detailText

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: nameText.right
                    anchors.leftMargin: Tokens.spacing.small
                    visible: rowItem.detail !== ""
                    text: rowItem.detail
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Cell {
                width: 80
                text: rowItem.pidText
            }

            Cell {
                width: 110
                text: rowItem.user
            }

            Cell {
                width: 90
                text: root.window.percent(rowItem.cpu)
                heat: rowItem.cpu * 4
            }

            Cell {
                width: 110
                text: root.window.bytes(rowItem.memory)
                heat: rowItem.memory / (2 * 1073741824)
            }

            Cell {
                width: 120
                text: rowItem.disk > 0 ? root.window.rate(rowItem.disk) : "—"
                heat: rowItem.disk / 52428800
            }
        }
    }

    // A right-aligned number, its background warmer the busier it is (like Windows')
    component Cell: Item {
        property alias text: cellText.text
        property real heat

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
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurface
        }
    }
}
