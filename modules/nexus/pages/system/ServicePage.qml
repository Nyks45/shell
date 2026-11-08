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
import qs.modules.nexus
import qs.modules.nexus.common

// One service or scheduled task: its state, starting/stopping it, whether it
// starts at boot, blocking it (mask) and its recent log. systemctl asks for
// the password itself for the computer's services (the shell's prompt).
PageBase {
    id: root

    readonly property string unit: nState.selectedUnit
    readonly property bool user: nState.selectedUnitUser
    readonly property bool isTimer: unit.endsWith(".timer")
    property var info: ({})
    // Services the running desktop needs: a stop or block asks twice
    readonly property bool vital: /^(systemd-|dbus|polkit|NetworkManager|greetd|sddm|gdm|lightdm|ly|udisks2|upower|accounts-daemon|pipewire|wireplumber|user@|getty@|seatd|elogind)/.test(unit)
    property string confirm // the action waiting for its second click

    readonly property bool running: info.ActiveState === "active" || info.ActiveState === "activating"
    readonly property string enabled: info.UnitFileState ?? ""

    function load(): void {
        showProc.command = [`${Paths.libdir}/caelestia-system`, "unit", unit, ...(user ? ["--user"] : [])];
        showProc.running = true;
    }

    function act(verb: list<string>, what: string): void {
        Admin.exec(["systemctl", ...(user ? ["--user"] : []), ...verb, unit], what, () => load());
    }

    // Asks for a second click first when the desktop relies on it
    function guarded(key: string, verb: list<string>, what: string): void {
        if (vital && confirm !== key) {
            confirm = key;
            confirmReset.restart();
            return;
        }
        confirm = "";
        act(verb, what);
    }

    function since(ts: string): string {
        if (!ts || ts === "n/a")
            return "";
        return ts.replace(/^\w{3} /, "");
    }

    title: unit.replace(/\.(service|timer)$/, "")
    isSubPage: true

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Non-visual (the page takes one item: they live in the column)
        Process {
            id: showProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.info = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }

        Timer {
            running: true
            interval: 4000
            repeat: true
            onTriggered: if (!showProc.running)
                root.load()
        }

        Timer {
            id: confirmReset

            interval: 4000
            onTriggered: root.confirm = ""
        }

        // ---- What it is ----------------------------------------------------
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: infoCol.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: infoCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.info.Description ?? root.unit
                    font: Tokens.font.body.medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: [root.info.ActiveState === "failed" ? Tr.tr("Failed (%1)").arg(root.info.Result ?? "") : root.running ? Tr.tr("Running since %1").arg(root.since(root.info.ActiveEnterTimestamp)) : Tr.tr("Stopped"), root.enabled === "enabled" ? Tr.tr("starts at boot") : root.enabled === "masked" ? Tr.tr("blocked") : root.enabled === "static" ? Tr.tr("started by others when needed") : "", root.user ? Tr.tr("your service") : ""].filter(x => x).join(" · ")
                    color: root.info.ActiveState === "failed" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [Number(root.info.MainPID) > 0 ? Tr.tr("process %1").arg(root.info.MainPID) : "", /^\d+$/.test(root.info.MemoryCurrent ?? "") ? Tr.tr("%1 memory").arg(Disks.human(Number(root.info.MemoryCurrent))) : "", Number(root.info.NRestarts) > 0 ? Tr.trN("restarted %n time", "restarted %n times", Number(root.info.NRestarts)) : "", root.info.TriggeredBy ? Tr.tr("started by %1").arg(root.info.TriggeredBy) : ""].filter(x => x).join(" · ")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.vital
                    text: Tr.tr("The system or your desktop needs this: stopping or blocking it can break things until a restart.")
                    color: Colours.palette.m3tertiary
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ---- Control it ----------------------------------------------------
        SectionHeader {
            text: Tr.tr("Control")
        }

        RowButton {
            visible: !root.running && root.enabled !== "masked"
            icon: "play_arrow"
            text: root.isTimer ? Tr.tr("Start the schedule") : Tr.tr("Start")
            disabled: Admin.busy
            onClicked: root.act(["start"], Tr.tr("Start %1").arg(root.title))
        }

        RowButton {
            visible: root.running
            icon: "stop"
            text: root.confirm === "stop" ? Tr.tr("Click again to stop it") : root.isTimer ? Tr.tr("Stop the schedule") : Tr.tr("Stop")
            disabled: Admin.busy
            onClicked: root.guarded("stop", ["stop"], Tr.tr("Stop %1").arg(root.title))
        }

        RowButton {
            visible: root.running && !root.isTimer
            icon: "restart_alt"
            text: root.confirm === "restart" ? Tr.tr("Click again to restart it") : Tr.tr("Restart")
            disabled: Admin.busy
            onClicked: root.guarded("restart", ["restart"], Tr.tr("Restart %1").arg(root.title))
        }

        RowButton {
            visible: root.isTimer
            icon: "bolt"
            text: Tr.tr("Run the task now")
            subtext: root.info.Triggers ?? ""
            disabled: Admin.busy
            onClicked: Admin.exec(["systemctl", ...(root.user ? ["--user"] : []), "start", root.unit.replace(/\.timer$/, ".service")], Tr.tr("Run %1").arg(root.title), () => root.load())
        }

        ToggleRow {
            visible: root.enabled === "enabled" || root.enabled === "disabled"
            text: Tr.tr("Start at boot")
            subtext: root.user ? Tr.tr("When you sign in") : Tr.tr("When the computer starts")
            checked: root.enabled === "enabled"
            onToggled: root.act([checked ? "enable" : "disable"], checked ? Tr.tr("Start %1 at boot").arg(root.title) : Tr.tr("Don't start %1 at boot").arg(root.title))
        }

        ToggleRow {
            visible: root.enabled !== "static" && root.enabled !== "" && root.enabled !== "generated" && root.enabled !== "transient"
            text: Tr.tr("Blocked")
            subtext: root.confirm === "mask" ? Tr.tr("Click again: nothing can start it then") : Tr.tr("Nothing can start it, not even other services (mask)")
            checked: root.enabled === "masked"
            onToggled: {
                if (checked && root.vital && root.confirm !== "mask") {
                    checked = false;
                    root.confirm = "mask";
                    confirmReset.restart();
                    return;
                }
                root.confirm = "";
                root.act([checked ? "mask" : "unmask"], checked ? Tr.tr("Block %1").arg(root.title) : Tr.tr("Unblock %1").arg(root.title));
            }
        }

        RowButton {
            visible: root.info.ActiveState === "failed"
            icon: "cleaning_services"
            text: Tr.tr("Forget the failure")
            subtext: Tr.tr("Clears its failed state (reset-failed)")
            onClicked: root.act(["reset-failed"], Tr.tr("Forget the failure of %1").arg(root.title))
        }

        // ---- Its log ------------------------------------------------------------
        SectionHeader {
            text: Tr.tr("Recent log")
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: logText.implicitHeight + Tokens.padding.large * 2

            StyledText {
                id: logText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                text: (root.info.log ?? []).length ? root.info.log.join("\n") : Tr.tr("Nothing logged")
                font: Tokens.font.mono.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WrapAnywhere
            }
        }

        NavRow {
            icon: "receipt_long"
            text: Tr.tr("Open its full log")
            onClicked: {
                root.nState.logUnit = root.unit;
                root.nState.goTo({
                    page: PageRegistry.pages.findIndex(p => p.id === "logs"),
                    path: []
                });
            }
        }
    }
}
