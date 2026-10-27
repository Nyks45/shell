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
import qs.services
import qs.utils
import qs.modules.nexus.common

// Apps started at login: the desktop files in ~/.config/autostart (where apps
// put themselves with "start on login"), run by hypr-settings.lua at login.
PageBase {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/autostart`
    // [{ file, name, icon, enabled }]
    property var entries: []

    function refresh(): void {
        listProc.running = false;
        listProc.running = true;
    }

    function setEnabled(file: string, on: bool): void {
        // Hidden=true in the [Desktop Entry] group turns an entry off (XDG)
        changeProc.exec(["sed", "-i", "-e", "/^Hidden=/d", ...(on ? [] : ["-e", "/^\\[Desktop Entry\\]/a Hidden=true"]), file]);
    }

    function add(app: DesktopEntry): void {
        const file = `${dir}/${app.id}.desktop`;
        // Terminal apps (btop, ...) need a terminal to show in
        const exec = app.execString || app.command.join(" ");
        const cmd = app.runInTerminal ? `${GlobalConfig.general.apps.terminal.join(" ")} -e ${exec}` : exec;
        const text = `[Desktop Entry]\nType=Application\nName=${app.name}\nExec=${cmd}\nIcon=${app.icon}\n`;
        changeProc.exec(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", dir, text, file]);
    }

    title: Tr.tr("Startup apps")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Start at login")
        }

        ToggleRow {
            first: true
            last: root.entries.length === 0
            text: Tr.tr("Start these apps at login")
            subtext: Tr.tr("Apps that start themselves (e.g. Steam's \"Run at startup\") show up here too")
            checked: HyprSettings.saved.autostart ?? true
            onToggled: HyprSettings.setAutostart(checked)
        }

        Repeater {
            model: root.entries

            ToggleRow {
                required property var modelData
                required property int index

                last: index === root.entries.length - 1
                disabled: !(HyprSettings.saved.autostart ?? true)
                text: modelData.name
                subtext: modelData.file.split("/").pop()
                checked: modelData.enabled
                onToggled: root.setEnabled(modelData.file, checked)
            }
        }

        SectionHeader {
            text: Tr.tr("Add")
        }

        AddRow {
            first: true
            last: true
            icon: "add"
            label: Tr.tr("Add an app")
            status: ""
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            id: listProc

            command: ["sh", "-c", "for f in \"$1\"/*.desktop; do [ -f \"$f\" ] || continue; echo \"@@FILE $f\"; cat \"$f\"; echo; done", "sh", root.dir]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = [];
                    for (const block of text.split("@@FILE ").slice(1)) {
                        const file = block.split("\n")[0].trim();
                        const main = block.split(/^\[(?!Desktop Entry\])/m)[0];
                        const get = k => main.match(new RegExp(`^${k}=(.*)$`, "m"))?.[1]?.trim() ?? "";
                        out.push({
                            file,
                            name: get("Name") || file.split("/").pop().replace(/\.desktop$/, ""),
                            icon: get("Icon"),
                            enabled: get("Hidden") !== "true" && get("X-GNOME-Autostart-enabled") !== "false"
                        });
                    }
                    root.entries = out.sort((a, b) => a.name.localeCompare(b.name));
                }
            }
        }

        Process {
            id: changeProc

            onExited: root.refresh()
        }
    }

    // Pick an installed app to start at login
    component AddRow: PopupRow {
        id: row

        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                // As tall as its items (a short list doesn't get an empty tail), up to the usual height
                implicitHeight: Math.min(contentHeight + topMargin + bottomMargin, CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight))

                model: [...DesktopEntries.applications.values].filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

                delegate: StateLayer {
                    id: appItem

                    required property DesktopEntry modelData

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: itemLayout.implicitHeight + itemLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        root.add(modelData);
                    }

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        IconImage {
                            asynchronous: true
                            implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                            source: Quickshell.iconPath(appItem.modelData.icon, "image-missing")
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: appItem.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
