pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Printers (CUPS): installing printing support, the printers and the default
// one (lpstat / lpoptions), adding one (system-config-printer).
PageBase {
    id: root

    property bool checked
    property bool hasCups
    property bool cupsRunning
    property bool hasConfigTool
    // [{ name, state }]
    property var printers: []
    property string defaultPrinter

    function refresh(): void {
        infoProc.running = true;
    }

    title: Tr.tr("Printers")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: infoProc

            running: true
            command: ["sh", "-c", `
command -v lpstat >/dev/null && echo has-cups
systemctl is-active --quiet cups.socket || systemctl is-active --quiet cups && echo running
command -v system-config-printer >/dev/null && echo has-tool
lpstat -d 2>/dev/null | sed -n 's/^.*: *//p' | sed 's/^/default=/'
lpstat -p 2>/dev/null | sed -n 's/^printer \\([^ ]*\\) \\(.*\\)$/printer=\\1\\t\\2/p'
`]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n");
                    root.hasCups = lines.includes("has-cups");
                    root.cupsRunning = lines.includes("running");
                    root.hasConfigTool = lines.includes("has-tool");
                    root.defaultPrinter = (lines.find(l => l.startsWith("default=")) ?? "").slice(8).trim();
                    root.printers = lines.filter(l => l.startsWith("printer=")).map(l => {
                        const [name, state] = l.slice(8).split("\t");
                        return {
                            name,
                            state: state ?? ""
                        };
                    });
                    root.checked = true;
                }
            }
        }

        Timer {
            id: recheck

            property int left

            interval: 4000
            repeat: true
            onTriggered: {
                root.refresh();
                if (--left <= 0)
                    stop();
            }
        }

        // No CUPS: offer to install it
        ConnectedRect {
            Layout.fillWidth: true
            visible: root.checked && (!root.hasCups || !root.cupsRunning)
            first: true
            last: true
            implicitHeight: installLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: installLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasCups ? Tr.tr("Printing is turned off") : Tr.tr("Printing isn't set up")
                    font: Tokens.font.body.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasCups ? Tr.tr("The printing service (CUPS) isn't running.") : Tr.tr("Installs the printing service (CUPS), a tool to add printers, and drivers for most printers, then starts it. Asks for your password.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    readonly property string what: root.hasCups ? Tr.tr("Turn printing on") : Tr.tr("Set up printing")
                    readonly property bool busy: Admin.jobs.some(j => j.what === what)

                    Layout.alignment: Qt.AlignRight
                    text: busy ? Tr.tr("Working…") : root.hasCups ? Tr.tr("Turn on") : Tr.tr("Set up")
                    type: TextButton.Filled
                    disabled: busy
                    onClicked: {
                        // systemctl asks polkit itself (the shell's prompt)
                        const start = () => Admin.exec(["systemctl", "enable", "--now", "cups.socket"], what, () => root.refresh());
                        if (root.hasCups)
                            start();
                        else
                            Admin.run("install", ["cups", "cups-pdf", "system-config-printer", "gutenprint", "foomatic-db-engine", "foomatic-db-ppds"], what, ok => {
                                if (ok)
                                    start();
                                else
                                    root.refresh();
                            });
                    }
                }
            }
        }

        SectionHeader {
            visible: root.hasCups && root.cupsRunning
            first: true
            text: Tr.tr("Printers")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.hasCups && root.cupsRunning && root.printers.length === 0
            text: Tr.tr("No printers yet. Most network printers are found by themselves when added.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: printerList

            model: root.hasCups && root.cupsRunning ? root.printers : []

            RowButton {
                required property var modelData
                required property int index

                first: index === 0
                icon: "print"
                text: modelData.name.replace(/_/g, " ")
                subtext: modelData.name === root.defaultPrinter ? Tr.tr("Default · %1").arg(modelData.state) : modelData.state
                trailingIcon: modelData.name === root.defaultPrinter ? "check" : ""
                onClicked: {
                    Quickshell.execDetached(["lpoptions", "-d", modelData.name]);
                    recheck.left = 1;
                    recheck.restart();
                }
            }
        }

        RowButton {
            visible: root.hasCups && root.cupsRunning
            first: root.printers.length === 0
            icon: "add"
            text: Tr.tr("Add a printer")
            subtext: root.hasConfigTool ? "" : Tr.tr("In the browser (CUPS)")
            onClicked: Quickshell.execDetached(root.hasConfigTool ? ["system-config-printer"] : ["xdg-open", "http://localhost:631/admin"])
        }

        RowButton {
            visible: root.hasCups && root.cupsRunning
            last: true
            icon: "open_in_new"
            text: Tr.tr("Print queue and more")
            subtext: Tr.tr("CUPS, in the browser")
            onClicked: Quickshell.execDetached(["xdg-open", "http://localhost:631/jobs"])
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: root.printers.length > 1
            text: Tr.tr("Click a printer to make it the default.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
