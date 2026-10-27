pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils
import qs.modules.nexus.common

// Hyprland plugins, managed with hyprpm: turn them on and off, update them
// (rebuilt for the running Hyprland) and add new ones.
PageBase {
    id: root

    // [{ name, repo, author, enabled, loaded }]
    property var plugins: []
    property list<string> loaded

    function refresh(): void {
        listProc.running = false;
        listProc.running = true;
        loadedProc.running = false;
        loadedProc.running = true;
    }

    // hyprpm changes its state with sudo: in a terminal, which can ask for
    // the password. The list catches up for a minute after.
    function inTerminal(script: string): void {
        Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "-e", "sh", "-c", `${script}; echo; read -p 'Press Enter to close' _`]);
        followUp.tries = 0;
        followUp.restart();
    }

    title: Tr.tr("Plugins")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Hyprland plugins")
        }

        InfoRow {
            visible: root.plugins.length === 0
            first: true
            last: true
            icon: "extension_off"
            label: Tr.tr("No plugins")
            subtext: Tr.tr("Add one below")
        }

        Repeater {
            model: root.plugins

            ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.plugins.length - 1
                text: modelData.name
                subtext: `${modelData.repo}${modelData.author ? ` · ${modelData.author}` : ""} · ${root.loaded.includes(modelData.name) ? Tr.tr("loaded") : Tr.tr("not loaded")}`
                checked: modelData.enabled
                // Loads or unloads it right away
                onToggled: root.inTerminal(`hyprpm ${checked ? "enable" : "disable"} ${modelData.name} && hyprpm reload -n`)
            }
        }

        SectionHeader {
            text: Tr.tr("Manage")
        }

        RowButton {
            first: true
            icon: "update"
            text: Tr.tr("Update plugins")
            subtext: Tr.tr("Rebuild them for the running Hyprland (after a Hyprland update); opens a terminal")
            onClicked: root.inTerminal("hyprpm update")
        }

        RowButton {
            last: true
            icon: "add"
            text: Tr.tr("Add a plugin")
            subtext: Tr.tr("From a git repository; opens a terminal")
            onClicked: root.inTerminal("read -p 'Repository URL: ' url && hyprpm add \"$url\" && hyprpm reload -n")
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            id: listProc

            command: ["hyprpm", "list"]
            stdout: StdioCollector {
                onStreamFinished: {
                    // → Repository NAME (by AUTHOR): / │ Plugin NAME / └─ enabled: true
                    const clean = text.replace(/\x1b\[[0-9;]*m/g, "");
                    const out = [];
                    let repo = "", author = "";
                    for (const line of clean.split("\n")) {
                        const r = line.match(/Repository (\S+)(?: \(by ([^)]*)\))?:/);
                        if (r) {
                            repo = r[1];
                            author = r[2] ?? "";
                            continue;
                        }
                        const p = line.match(/Plugin (\S+)/);
                        if (p) {
                            out.push({
                                name: p[1],
                                repo,
                                author,
                                enabled: false
                            });
                            continue;
                        }
                        const e = line.match(/enabled: (\w+)/);
                        if (e && out.length)
                            out[out.length - 1].enabled = e[1] === "true";
                    }
                    root.plugins = out;
                }
            }
        }

        Process {
            id: loadedProc

            command: ["hyprctl", "plugin", "list"]
            stdout: StdioCollector {
                onStreamFinished: root.loaded = Strings.allMatches(text, /^Plugin (\S+)/gm).map(m => m[1])
            }
        }

        Timer {
            id: followUp

            property int tries

            interval: 3000
            repeat: true
            onTriggered: {
                root.refresh();
                if (++tries >= 20)
                    stop();
            }
        }
    }
}
