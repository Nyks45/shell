pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
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

    // Commands added here (not apps): custom-<n>.desktop files
    readonly property var customEntries: entries.filter(e => e.file.split("/").pop().startsWith("custom-"))

    function addCommand(cmd: string): void {
        const name = cmd.split(/\s+/)[0].split("/").pop();
        let n = 1;
        while (entries.some(e => e.file.endsWith(`/custom-${n}.desktop`)))
            n++;
        const text = `[Desktop Entry]\nType=Application\nName=${name}\nComment=Added in Settings\nExec=${cmd}\nIcon=utilities-terminal\n`;
        changeProc.exec(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "sh", dir, text, `${dir}/custom-${n}.desktop`]);
    }

    title: Tr.tr("Startup apps")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: Tr.tr("Start at login")
        }

        ToggleRow {
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

        RowButton {
            icon: "add"
            text: Tr.tr("Add an app")
            subtext: Tr.tr("Choose an installed app to start at login")
            onClicked: appPicker.openPicker({
                header: Tr.tr("Add a startup app"),
                excludeIds: root.entries.map(e => e.file.split("/").pop().replace(/\.desktop$/, "")),
                onPicked: item => {
                    if (item.desktopEntry)
                        root.add(item.desktopEntry);
                }
            })
        }

        SectionHeader {
            text: Tr.tr("Commands")
        }

        StringListEditor {
            values: root.customEntries.map(e => e.exec)
            placeholderText: Tr.tr("A command to run at login, e.g. syncthing --no-browser")
            emptyText: Tr.tr("Anything that isn't an app: a script, a tool with options")
            onEdited: v => {
                const before = root.customEntries;
                // Removed: delete their files; added: write one
                for (const e of before)
                    if (!v.includes(e.exec))
                        changeProc.exec(["rm", "-f", e.file]);
                for (const cmd of v)
                    if (!before.some(e => e.exec === cmd))
                        root.addCommand(cmd);
            }
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
                            exec: get("Exec"),
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

        AppPickerDialog {
            id: appPicker

            hostFlickable: root.flickable
        }
    }
}
