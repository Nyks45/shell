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
import qs.utils
import qs.modules.nexus.common

// The system's log (journald): by boot, how serious, service and text;
// what went wrong in the previous boot; crash reports to copy for a bug
// report.
PageBase {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-system`
    property string boot: "0" // 0 = this one, -1 = the one before...
    property string priority: "4" // "3" errors, "4" warnings and worse, "" everything
    property string unit: nState.logUnit
    property string search
    property var entries: []
    property var boots: []
    property var crashes: []
    property bool loading
    property string copied

    function load(): void {
        loading = true;
        logProc.command = [helper, "logs", "--boot", boot, "--lines", "400", ...(priority ? ["--priority", priority] : []), ...(unit ? ["--unit", unit] : []), ...(search ? ["--grep", search] : [])];
        logProc.running = true;
    }

    function bootLabel(b: var): string {
        const when = new Date(b.first_entry / 1000).toLocaleString(Qt.locale(), Locale.ShortFormat);
        return b.index === 0 ? Tr.tr("This boot (%1)").arg(when) : b.index === -1 ? Tr.tr("Previous boot (%1)").arg(when) : when;
    }

    function copy(text: string, what: string): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text]);
        copied = what;
        copiedReset.restart();
    }

    title: Tr.tr("Logs")

    Component.onCompleted: {
        load();
        bootsProc.running = true;
        crashProc.running = true;
    }
    Component.onDestruction: nState.logUnit = ""
    onBootChanged: load()
    onPriorityChanged: load()
    onUnitChanged: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Non-visual (the page takes one item: they live in the column)
        Process {
            id: logProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.entries = JSON.parse(text);
                    } catch (e) {
                        root.entries = [];
                    }
                    root.loading = false;
                }
            }
        }

        Process {
            id: bootsProc

            command: [root.helper, "boots"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.boots = JSON.parse(text).sort((a, b) => b.index - a.index);
                    } catch (e) {}
                }
            }
        }

        Process {
            id: crashProc

            command: [root.helper, "crashes"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.crashes = JSON.parse(text).slice(0, 20);
                    } catch (e) {}
                }
            }
        }

        Process {
            id: crashInfo

            property string name

            stdout: StdioCollector {
                onStreamFinished: root.copy(text, Tr.tr("The crash report of %1 is copied: paste it into the bug report.").arg(crashInfo.name))
            }
        }

        Timer {
            id: searchDelay

            interval: 400
            onTriggered: root.load()
        }

        Timer {
            id: copiedReset

            interval: 6000
            onTriggered: root.copied = ""
        }

        // ---- What to show ---------------------------------------------------
        RowButton {
            icon: "error"
            text: Tr.tr("What went wrong in the previous boot")
            subtext: Tr.tr("Its errors, e.g. after a crash or a freeze")
            onClicked: {
                root.unit = "";
                root.priority = "3";
                root.boot = "-1";
            }
        }

        SelectRow {
            label: Tr.tr("Boot")
            menuItems: bootItems.instances
            active: bootItems.instances.find(i => i.value === root.boot) ?? null
            fallbackText: root.boot === "0" ? Tr.tr("This boot") : root.boot
            onSelected: item => root.boot = item.value

            Variants {
                id: bootItems

                model: root.boots.slice(0, 15)

                MenuItem {
                    required property var modelData
                    readonly property string value: String(modelData.index)

                    text: root.bootLabel(modelData)
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: [["3", Tr.tr("Errors")], ["4", Tr.tr("Warnings and errors")], ["", Tr.tr("Everything")]]

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.priority === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.priority = modelData[0]
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            StyledTextField {
                Layout.fillWidth: true
                text: root.unit
                placeholderText: Tr.tr("Service (e.g. NetworkManager)")
                leadingIcon: "settings"
                onEditingFinished: root.unit = text.trim()
            }

            StyledTextField {
                Layout.fillWidth: true
                placeholderText: Tr.tr("Text in the message")
                leadingIcon: "search"
                onTextChanged: {
                    root.search = text;
                    searchDelay.restart();
                }
            }
        }

        // ---- The lines ------------------------------------------------------
        SectionHeader {
            text: root.loading ? Tr.tr("Reading…") : Tr.tr("%1 lines, newest first").arg(root.entries.length)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.copied !== ""
            text: root.copied
            color: Colours.palette.m3primary
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        RowButton {
            visible: root.entries.length > 0
            icon: "content_copy"
            text: Tr.tr("Copy these lines")
            onClicked: root.copy(root.entries.map(e => `${new Date(e.time).toISOString()} ${e.ident}: ${e.message}`).reverse().join("\n"), Tr.tr("The lines are copied."))
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: root.entries.length > 0
            implicitHeight: lines.implicitHeight + Tokens.padding.large * 2

            Column {
                id: lines

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.entries

                    StyledText {
                        required property var modelData

                        width: lines.width
                        text: `${Qt.formatDateTime(new Date(modelData.time), "HH:mm:ss")}  ${modelData.ident}  ${modelData.message}`
                        color: modelData.priority <= 3 ? Colours.palette.m3error : modelData.priority === 4 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.mono.small
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !root.loading && root.entries.length === 0
            text: Tr.tr("Nothing matches")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        // ---- Crash reports -----------------------------------------------------
        SectionHeader {
            text: Tr.tr("Crash reports")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.crashes.length === 0
            text: Tr.tr("No app crashed recently")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.crashes

            RowButton {
                required property var modelData
                readonly property string name: (modelData.exe ?? "").split("/").pop()

                icon: "bug_report"
                text: name || Tr.tr("Unknown program")
                subtext: Tr.tr("%1 · signal %2 · click to copy the report").arg(new Date(modelData.time / 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)).arg(modelData.sig)
                onClicked: {
                    crashInfo.name = name;
                    crashInfo.command = [root.helper, "crash", String(modelData.pid)];
                    crashInfo.running = true;
                }
            }
        }
    }
}
