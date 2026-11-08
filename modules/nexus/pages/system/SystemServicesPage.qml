pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// The system's services (systemd): the computer's, the user's own and the
// scheduled tasks (timers), with what they do and whether they run; one
// opens its page (start, stop, start at boot, its log).
PageBase {
    id: root

    property string tab: "system" // "system", "user", "timers"
    property string filter: "running" // "all", "running", "failed", "enabled"
    property string search
    property var units: []
    property var timers: []
    property bool loading: true
    // A short list first; "Show all" lifts it (back to short on another tab or filter)
    property bool showAll

    readonly property var matching: {
        const q = search.toLowerCase();
        const list = (tab === "timers" ? timers : units).filter(u => {
            const name = (u.name ?? u.unit) + " " + (u.description ?? "");
            if (q && !name.toLowerCase().includes(q))
                return false;
            if (tab === "timers")
                return true;
            if (filter === "running")
                return u.active === "active" && u.sub !== "exited";
            if (filter === "failed")
                return u.active === "failed";
            if (filter === "enabled")
                return u.enabled === "enabled";
            return true;
        });
        return list;
    }
    readonly property var shown: showAll || search ? matching : matching.slice(0, 12)

    function load(): void {
        loading = true;
        const helper = `${Paths.libdir}/caelestia-system`;
        listProc.command = tab === "timers" ? [helper, "timers"] : [helper, "units", ...(tab === "user" ? ["--user"] : [])];
        listProc.running = true;
    }

    function open(name: string, user: bool): void {
        nState.selectedUnit = name;
        nState.selectedUnitUser = user;
        nState.openSubPage(1);
    }

    function when(us: real): string {
        if (!(us > 0))
            return "";
        const d = new Date(us / 1000);
        return d.toLocaleString(Qt.locale(), Locale.ShortFormat);
    }

    title: Tr.tr("System services")

    Component.onCompleted: load()
    onTabChanged: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Non-visual (the page takes one item: it lives in the column)
        Process {
            id: listProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        if (root.tab === "timers")
                            root.timers = data;
                        else
                            root.units = data;
                    } catch (e) {}
                    root.loading = false;
                }
            }
        }

        Timer {
            // Keeps the states current while the page is open
            running: true
            interval: 5000
            repeat: true
            onTriggered: if (!listProc.running)
                root.load()
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            Repeater {
                model: [["system", Tr.tr("This computer")], ["user", Tr.tr("Yours")], ["timers", Tr.tr("Scheduled tasks")]]

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.tab === modelData[0]
                    type: TextButton.Tonal
                    onClicked: {
                        root.tab = modelData[0];
                        root.showAll = false;
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: root.tab !== "timers"
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: [["running", Tr.tr("Running")], ["failed", Tr.tr("Failed")], ["enabled", Tr.tr("Start at boot")], ["all", Tr.tr("All")]]

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.filter === modelData[0]
                    type: TextButton.Tonal
                    onClicked: {
                        root.filter = modelData[0];
                        root.showAll = false;
                    }
                }
            }
        }

        StyledTextField {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            placeholderText: Tr.tr("Find a service")
            leadingIcon: "search"
            onTextChanged: root.search = text
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.shown.length === 0
            text: root.loading ? Tr.tr("Reading…") : Tr.tr("Nothing here")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.shown

            NavRow {
                required property var modelData
                readonly property bool isTimer: root.tab === "timers"
                readonly property string unitState: isTimer ? "" : modelData.active

                icon: isTimer ? "schedule" : unitState === "failed" ? "error" : unitState === "active" ? (modelData.sub === "exited" ? "check_circle" : "play_circle") : "pause_circle"
                text: (modelData.name ?? modelData.unit).replace(/\.(service|timer)$/, "")
                subtext: isTimer ? [modelData.description, modelData.next ? Tr.tr("next %1").arg(root.when(modelData.next)) : Tr.tr("not scheduled"), modelData.last ? Tr.tr("last %1").arg(root.when(modelData.last)) : ""].filter(x => x).join(" · ") : [modelData.description, unitState === "active" ? (modelData.sub === "exited" ? Tr.tr("ran and finished") : Tr.tr("running")) : unitState === "failed" ? Tr.tr("failed") : Tr.tr("stopped"), modelData.enabled === "enabled" ? Tr.tr("starts at boot") : modelData.enabled === "masked" ? Tr.tr("blocked") : ""].filter(x => x).join(" · ")
                iconLabel.color: unitState === "failed" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                onClicked: root.open(modelData.name ?? modelData.unit, root.tab === "user")
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: root.shown.length < root.matching.length
            icon: "expand_more"
            text: Tr.tr("Show all %1").arg(root.matching.length)
            onClicked: root.showAll = true
        }
    }
}
