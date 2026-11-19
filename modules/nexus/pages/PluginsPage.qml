pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

// Hyprland plugins, managed with hyprpm: turn them on and off, update them
// (rebuilt for the running Hyprland) and add new ones. Changes take effect on
// next sign-in instead of hot-loading into the running compositor.
PageBase {
    id: root

    // [{ name, repo, author, enabled }]
    property var plugins: []
    property list<string> loaded
    readonly property bool hasPendingChanges: plugins.some(p => p.enabled !== loaded.includes(p.name))

    function refresh(): void {
        listProc.running = false;
        listProc.running = true;
        loadedProc.running = false;
        loadedProc.running = true;
    }

    // hyprpm changes its state with sudo: in a terminal, which can ask for
    // the password. The list refreshes as soon as the terminal closes.
    function inTerminal(script: string): void {
        if (termProc.running)
            return;
        termProc.command = [...GlobalConfig.general.apps.terminal, "-e", "sh", "-c", `${script}; echo; read -p 'Press Enter to close' _`];
        termProc.running = true;
    }

    title: Tr.tr("Plugins")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        InfoRow {
            visible: root.hasPendingChanges
            icon: "restart_alt"
            iconColour: Colours.palette.m3primary
            label: Tr.tr("Sign out and back in to apply plugin changes")
            subtext: Tr.tr("At least one plugin is queued to load or unload on your next sign-in.")
        }

        SectionHeader {
            first: !root.hasPendingChanges
            text: Tr.tr("Hyprland plugins")
        }

        InfoRow {
            visible: root.plugins.length === 0
            icon: "extension_off"
            label: Tr.tr("No plugins")
            subtext: Tr.tr("Add one below")
        }

        Repeater {
            model: root.plugins

            ToggleRow {
                required property var modelData
                required property int index
                readonly property bool isLoaded: root.loaded.includes(modelData.name)
                readonly property string statusText: {
                    if (modelData.enabled && isLoaded)
                        return Tr.tr("loaded");
                    if (!modelData.enabled && !isLoaded)
                        return Tr.tr("off");
                    if (modelData.enabled && !isLoaded)
                        return Tr.tr("enabled · loads on next sign-in");
                    return Tr.tr("disabled · unloads on next sign-in");
                }

                text: modelData.name
                subtext: `${modelData.repo}${modelData.author ? ` · ${modelData.author}` : ""} · ${statusText}`
                checked: modelData.enabled
                disabled: termProc.running
                onToggled: {
                    const want = checked;
                    checked = Qt.binding(() => modelData.enabled);
                    const safe = modelData.name.replace(/[^A-Za-z0-9._-]/g, "");
                    if (!safe)
                        return;
                    root.inTerminal(`hyprpm ${want ? "enable" : "disable"} '${safe}'`);
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Manage")
        }

        RowButton {
            icon: "update"
            text: Tr.tr("Update plugins")
            subtext: Tr.tr("Rebuild them for the running Hyprland (after a Hyprland update); opens a terminal")
            disabled: termProc.running
            onClicked: root.inTerminal("hyprpm update")
        }

        RowButton {
            icon: "add"
            text: Tr.tr("Add a plugin")
            subtext: Tr.tr("From a git repository; opens a terminal")
            disabled: termProc.running
            onClicked: root.inTerminal("read -p 'Repository URL: ' url && hyprpm add \"$url\"")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Plugin changes take effect the next time you sign in. Loading or unloading Hyprland plugins live can crash the desktop.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Process {
            id: termProc

            onExited: root.refresh()
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
    }
}
