pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// systemd services, the system's or this user's: state, and start / stop / restart (the
// system's ask for the password through the shell's own prompt)
Item {
    id: root

    required property var window

    property bool user
    property var units: []
    property var bootStates: ({}) // unit -> enabled / disabled / static ...
    property string logUnit
    property string logText
    property string selected
    property string filter

    readonly property var shown: {
        const f = filter.toLowerCase();
        return units.filter(u => !f || u.unit.toLowerCase().includes(f) || (u.description ?? "").toLowerCase().includes(f));
    }
    readonly property var selectedUnit: units.find(u => u.unit === selected) ?? null

    function refresh(): void {
        if (!lister.running)
            lister.running = true;
    }

    function act(verb: string): void {
        if (!selected)
            return;
        actor.command = ["systemctl", ...(user ? ["--user"] : []), verb, selected];
        actor.running = true;
    }

    function showLog(unit: string): void {
        logUnit = unit;
        logText = qsTr("Loading…");
        logger.command = ["journalctl", ...(user ? ["--user-unit", unit] : ["-u", unit]), "-n", "300", "--no-pager", "-o", "short-iso"];
        logger.running = true;
    }

    onUserChanged: {
        units = [];
        selected = "";
        refresh();
        fileLister.running = true;
    }

    Process {
        id: fileLister

        command: ["systemctl", ...(root.user ? ["--user"] : []), "list-unit-files", "--type=service", "--output=json", "--no-pager"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {};
                    for (const f of JSON.parse(text))
                        map[f.unit_file] = f.state;
                    root.bootStates = map;
                } catch (e) {}
            }
        }
    }

    Process {
        id: logger

        stdout: StdioCollector {
            onStreamFinished: root.logText = text.trim() || qsTr("No log entries")
        }
    }

    Process {
        id: lister

        command: ["systemctl", ...(root.user ? ["--user"] : []), "list-units", "--type=service", "--all", "--output=json", "--no-pager"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    list.sort((a, b) => (a.active === "active" ? 0 : 1) - (b.active === "active" ? 0 : 1) || a.unit.localeCompare(b.unit));
                    root.units = list;
                } catch (e) {}
            }
        }
    }

    Process {
        id: actor

        onExited: {
            root.refresh();
            fileLister.running = true;
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 5000
        onTriggered: root.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                Layout.preferredWidth: 340
                placeholderText: qsTr("Search services")
                leadingIcon: "search"
                onTextChanged: root.filter = text
            }

            TabButton {
                label: qsTr("System")
                selected: !root.user
                onClicked: root.user = false
            }

            TabButton {
                label: qsTr("User")
                selected: root.user
                onClicked: root.user = true
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                Layout.maximumWidth: 260
                elide: Text.ElideRight
                text: qsTr("%1 running · %2 in all").arg(root.units.filter(u => u.sub === "running").length).arg(root.units.length)
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: Item {
                id: row

                required property var modelData

                width: list.width
                implicitHeight: 36

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    color: root.selected === row.modelData.unit ? Colours.palette.m3secondaryContainer : "transparent"

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: root.selected = row.modelData.unit
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: row.modelData.sub === "running" ? Colours.palette.m3primary : row.modelData.active === "failed" ? Colours.palette.m3error : Colours.palette.m3outlineVariant
                    }

                    StyledText {
                        Layout.preferredWidth: 300
                        elide: Text.ElideRight
                        text: row.modelData.unit
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: row.modelData.description ?? ""
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.preferredWidth: 110
                        horizontalAlignment: Text.AlignRight
                        text: {
                            const b = root.bootStates[row.modelData.unit] ?? "";
                            return b === "enabled" ? qsTr("At boot") : b === "disabled" ? qsTr("Manual") : b === "static" ? qsTr("Static") : b;
                        }
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.preferredWidth: 140
                        horizontalAlignment: Text.AlignRight
                        text: `${row.modelData.active} (${row.modelData.sub})`
                        font: Tokens.font.label.medium
                        color: row.modelData.active === "failed" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

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
                    text: root.selectedUnit ? `${root.selectedUnit.unit} — ${root.selectedUnit.description ?? ""}` : qsTr("Select a service")
                }

                TabButton {
                    usable: root.selectedUnit !== null
                    label: qsTr("Logs")
                    icon: "receipt_long"
                    onClicked: root.showLog(root.selected)
                }

                TabButton {
                    readonly property string boot: root.bootStates[root.selected] ?? ""

                    visible: boot === "enabled" || boot === "disabled"
                    label: boot === "enabled" ? qsTr("Don't start at boot") : qsTr("Start at boot")
                    icon: boot === "enabled" ? "toggle_on" : "toggle_off"
                    onClicked: root.act(boot === "enabled" ? "disable" : "enable")
                }

                TabButton {
                    usable: root.selectedUnit !== null && root.selectedUnit.active !== "active"
                    label: qsTr("Start")
                    icon: "play_arrow"
                    onClicked: root.act("start")
                }

                TabButton {
                    usable: root.selectedUnit !== null && root.selectedUnit.active === "active"
                    label: qsTr("Restart")
                    icon: "restart_alt"
                    onClicked: root.act("restart")
                }

                TabButton {
                    usable: root.selectedUnit !== null && root.selectedUnit.active === "active"
                    label: qsTr("Stop")
                    icon: "stop"
                    danger: true
                    onClicked: root.act("stop")
                }
            }
        }
    }

    // A service's recent log (journalctl)
    MouseArea {
        anchors.fill: parent
        visible: root.logUnit !== ""
        onClicked: root.logUnit = ""
    }

    StyledRect {
        visible: root.logUnit !== ""
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Log: %1").arg(root.logUnit)
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                TabButton {
                    label: qsTr("Refresh")
                    icon: "refresh"
                    onClicked: root.showLog(root.logUnit)
                }

                TabButton {
                    icon: "close"
                    onClicked: root.logUnit = ""
                }
            }

            Flickable {
                id: logView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: logLabel.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: logView
                }

                TextEdit {
                    id: logLabel

                    width: logView.width - 12
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.WrapAnywhere
                    text: root.logText
                    font.family: "monospace"
                    font.pointSize: 9
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }
}
