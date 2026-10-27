pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Monitors (resolution, refresh rate, scale, rotation, VRR, HDR) and night
// light. A display change has to be kept within 15 seconds or it's undone, in
// case the screen went black.
PageBase {
    id: root

    property var monitors: []
    property string selectedName
    readonly property var monitor: monitors.find(m => m.name === selectedName) ?? monitors[0] ?? null

    // "2560x1440" -> [rates], from the monitor's modes
    readonly property var modes: {
        const out = {};
        for (const m of monitor?.availableModes ?? []) {
            const match = m.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            if (!match)
                continue;
            const res = `${match[1]}x${match[2]}`;
            (out[res] = out[res] ?? []).push(parseFloat(match[3]));
        }
        return out;
    }
    readonly property list<string> resolutions: Object.keys(modes).sort((a, b) => {
        const [aw, ah] = a.split("x").map(Number), [bw, bh] = b.split("x").map(Number);
        return bw * bh - aw * ah;
    })
    readonly property string resolution: monitor ? `${monitor.width}x${monitor.height}` : ""

    // Scales Hyprland takes for this resolution: the screen divided into
    // whole pixels (1.5 on 2560 x 1440 isn't one; 1.6 is). The current one too.
    readonly property list<real> scales: {
        if (!monitor)
            return [1];
        const whole = x => Math.abs(x - Math.round(x)) < 0.01;
        const valid = [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.5, 3].filter(s => whole(monitor.width / s) && whole(monitor.height / s));
        if (!valid.some(s => Math.abs(s - monitor.scale) < 0.01))
            valid.push(monitor.scale);
        return valid.sort((a, b) => a - b);
    }

    // Kept-or-undone after a change
    property var undo: null
    property int countdown

    readonly property var night: HyprSettings.saved.nightLight ?? {}
    property bool sunsetInstalled
    readonly property string sunsetConf: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/hypr/hyprsunset.conf`

    // This monitor's settings now, as hypr-settings keeps them
    function currentSettings(): var {
        const m = monitor;
        return {
            description: m.description,
            mode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`,
            position: `${m.x}x${m.y}`,
            scale: m.scale,
            vrr: HyprSettings.saved.monitors?.[m.name]?.vrr ?? (m.vrr ? 1 : 0),
            transform: m.transform,
            hdr: m.colorManagementPreset === "hdr"
        };
    }

    function change(changes: var): void {
        if (!monitor)
            return;
        const name = monitor.name;
        if (!undo)
            undo = {
                name,
                settings: HyprSettings.saved.monitors?.[name] ?? null
            };
        HyprSettings.setMonitor(name, Object.assign(currentSettings(), changes));
        countdown = 15;
        countdownTimer.restart();
        refreshTimer.restart();
    }

    function keep(): void {
        undo = null;
        countdownTimer.stop();
    }

    function revert(): void {
        if (!undo)
            return;
        if (undo.settings)
            HyprSettings.setMonitor(undo.name, undo.settings);
        else
            HyprSettings.forgetMonitor(undo.name);
        undo = null;
        countdownTimer.stop();
        refreshTimer.restart();
        rebind();
    }

    // Picking from a menu or flipping a switch replaces the row's binding with
    // the picked value: after going back, follow the monitor again.
    function rebind(): void {
        resRow.active = Qt.binding(() => resItems.instances.find(i => i.value === root.resolution) ?? null);
        rateRow.active = Qt.binding(() => rateItems.instances.find(i => Math.abs(i.value - (root.monitor?.refreshRate ?? 0)) < 0.05) ?? null);
        scaleRow.active = Qt.binding(() => scaleItems.instances.find(i => Math.abs(i.value - (root.monitor?.scale ?? 1)) < 0.01) ?? null);
        orientationRow.active = Qt.binding(() => orientationRow.menuItems.find(i => i.value === (root.monitor?.transform ?? 0)) ?? null);
        vrrRow.active = Qt.binding(() => vrrRow.menuItems.find(i => i.value === (HyprSettings.saved.monitors?.[root.monitor?.name]?.vrr ?? (root.monitor?.vrr ? 1 : 0))) ?? null);
        hdrRow.checked = Qt.binding(() => root.monitor?.colorManagementPreset === "hdr");
    }

    function refresh(): void {
        monitorsProc.running = false;
        monitorsProc.running = true;
    }

    // Night light: hyprsunset, scheduled by its config (identity by day)
    function writeSunsetConf(n: var): void {
        const temp = n.temperature ?? 4000;
        const from = n.from ?? "20:00", to = n.to ?? "07:00";
        const body = n.always ? `profile {\n    time = 0:00\n    temperature = ${temp}\n}\n` : `profile {\n    time = ${to}\n    identity = true\n}\n\nprofile {\n    time = ${from}\n    temperature = ${temp}\n}\n`;
        sunsetFile.setText(`# Written by Caelestia's settings app (Display > Night light).\n\n${body}`);
    }

    function setNight(changes: var): void {
        const n = Object.assign({}, night, changes);
        HyprSettings.setNightLight(changes);
        writeSunsetConf(n);
        // (Re)start or stop it now; at login hypr-settings.lua starts it
        Quickshell.execDetached(["sh", "-c", n.enabled ? "pkill -x hyprsunset; sleep 0.3; exec hyprsunset" : "pkill -x hyprsunset"]);
    }

    title: Tr.tr("Display")

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Keep these settings?
        ConnectedRect {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.large
            visible: root.undo !== null
            first: true
            last: true
            implicitHeight: keepLayout.implicitHeight + Tokens.padding.large * 2
            color: Colours.palette.m3secondaryContainer

            RowLayout {
                id: keepLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                anchors.leftMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Tr.tr("Keep these display settings?")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Going back to the previous ones in %1 s").arg(root.countdown)
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSecondaryContainer
                        elide: Text.ElideRight
                    }
                }

                TextButton {
                    text: Tr.tr("Revert")
                    type: TextButton.Text
                    onClicked: root.revert()
                }

                TextButton {
                    text: Tr.tr("Keep")
                    onClicked: root.keep()
                }
            }
        }

        SectionHeader {
            first: true
            text: Tr.tr("Monitor")
        }

        SelectRow {
            visible: root.monitors.length > 1
            first: true
            label: Tr.tr("Monitor")
            subtext: root.monitor?.description ?? ""
            menuItems: monitorItems.instances
            active: monitorItems.instances.find(i => i.value === root.monitor?.name) ?? null
            onSelected: item => root.selectedName = item.value

            Variants {
                id: monitorItems

                model: root.monitors

                MenuItem {
                    required property var modelData

                    text: `${modelData.name} (${modelData.model || modelData.make})`
                    value: modelData.name
                }
            }
        }

        InfoRow {
            visible: root.monitors.length <= 1
            first: true
            label: root.monitor?.model || root.monitor?.name || Tr.tr("No monitor")
            subtext: root.monitor ? [root.monitor.make, root.monitor.name].filter(s => s && s !== root.monitor.model).join(" · ") : ""
            icon: "monitor"
        }

        SelectRow {
            id: resRow

            label: Tr.tr("Resolution")
            subtext: Tr.tr("The first one is the screen's own")
            menuItems: resItems.instances
            active: resItems.instances.find(i => i.value === root.resolution) ?? null
            fallbackText: root.resolution.replace("x", " × ")
            onSelected: item => {
                // Keep the refresh rate if this resolution has it, else its fastest
                const rates = root.modes[item.value] ?? [];
                const rate = rates.find(r => Math.abs(r - root.monitor.refreshRate) < 0.5) ?? Math.max(...rates);
                root.change({
                    mode: `${item.value}@${rate.toFixed(2)}`
                });
            }

            Variants {
                id: resItems

                model: root.resolutions

                MenuItem {
                    required property string modelData
                    required property int index

                    text: index === 0 ? Tr.tr("%1 (recommended)").arg(modelData.replace("x", " × ")) : modelData.replace("x", " × ")
                    value: modelData
                }
            }
        }

        SelectRow {
            id: rateRow

            label: Tr.tr("Refresh rate")
            subtext: Tr.tr("How many times a second the picture updates")
            menuItems: rateItems.instances
            active: rateItems.instances.find(i => Math.abs(i.value - (root.monitor?.refreshRate ?? 0)) < 0.05) ?? null
            fallbackText: Tr.tr("%1 Hz").arg(Math.round(root.monitor?.refreshRate ?? 0))
            onSelected: item => root.change({
                    mode: `${root.resolution}@${item.value.toFixed(2)}`
                })

            Variants {
                id: rateItems

                model: [...new Set((root.modes[root.resolution] ?? []).map(r => r.toFixed(2)))].map(Number).sort((a, b) => b - a)

                MenuItem {
                    required property real modelData

                    text: Tr.tr("%1 Hz").arg(Math.abs(modelData - Math.round(modelData)) < 0.05 ? Math.round(modelData) : modelData.toFixed(2))
                    value: modelData
                }
            }
        }

        SelectRow {
            id: scaleRow

            label: Tr.tr("Scale")
            subtext: Tr.tr("Size of text, apps and the shell")
            menuItems: scaleItems.instances
            active: scaleItems.instances.find(i => Math.abs(i.value - (root.monitor?.scale ?? 1)) < 0.01) ?? null
            fallbackText: `${Math.round((root.monitor?.scale ?? 1) * 100)}%`
            onSelected: item => root.change({
                    scale: item.value
                })

            Variants {
                id: scaleItems

                model: root.scales

                MenuItem {
                    required property real modelData

                    text: `${Math.round(modelData * 100)}%`
                    value: modelData
                }
            }
        }

        SelectRow {
            id: orientationRow

            label: Tr.tr("Orientation")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Landscape")
                    value: 0
                },
                MenuItem {
                    text: Tr.tr("Portrait")
                    value: 1
                },
                MenuItem {
                    text: Tr.tr("Landscape (flipped)")
                    value: 2
                },
                MenuItem {
                    text: Tr.tr("Portrait (flipped)")
                    value: 3
                }
            ]
            active: menuItems.find(i => i.value === (root.monitor?.transform ?? 0)) ?? null
            onSelected: item => root.change({
                    transform: item.value
                })
        }

        SelectRow {
            id: vrrRow

            label: Tr.tr("Variable refresh rate")
            subtext: Tr.tr("Matches the refresh rate to games to avoid tearing; some screens flicker with it")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Off")
                    value: 0
                },
                MenuItem {
                    text: Tr.tr("On")
                    value: 1
                },
                MenuItem {
                    text: Tr.tr("Fullscreen apps only")
                    value: 2
                }
            ]
            active: menuItems.find(i => i.value === (HyprSettings.saved.monitors?.[root.monitor?.name]?.vrr ?? (root.monitor?.vrr ? 1 : 0))) ?? null
            onSelected: item => root.change({
                    vrr: item.value
                })
        }

        ToggleRow {
            id: hdrRow

            last: true
            text: Tr.tr("HDR")
            subtext: Tr.tr("Brighter highlights and wider colours on HDR screens (experimental)")
            checked: root.monitor?.colorManagementPreset === "hdr"
            onToggled: root.change({
                hdr: checked
            })
        }

        // Night light
        SectionHeader {
            text: Tr.tr("Night light")
        }

        RowButton {
            visible: !root.sunsetInstalled
            first: true
            last: true
            icon: "download"
            text: Tr.tr("Install night light")
            subtext: Tr.tr("Needs hyprsunset; opens a terminal to install it")
            onClicked: {
                Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "-e", "sh", "-c", "sudo pacman -S --needed hyprsunset; echo; read -p 'Press Enter to close' _"]);
                installCheck.restart();
            }
        }

        ToggleRow {
            visible: root.sunsetInstalled
            first: true
            text: Tr.tr("Night light")
            subtext: Tr.tr("Warmer colours in the evening, easier on the eyes")
            checked: root.night.enabled ?? false
            onToggled: root.setNight({
                enabled: checked
            })
        }

        SliderRow {
            visible: root.sunsetInstalled
            icon: "thermostat"
            label: Tr.tr("Warmth")
            valueLabel: `${root.night.temperature ?? 4000} K`
            // 6500 K (none) .. 2500 K (very warm)
            value: (6500 - (root.night.temperature ?? 4000)) / 4000
            onMoved: v => root.setNight({
                    temperature: Math.round((6500 - v * 4000) / 100) * 100
                })
        }

        ToggleRow {
            visible: root.sunsetInstalled
            text: Tr.tr("All day")
            subtext: Tr.tr("Instead of only in the evening and at night")
            checked: root.night.always ?? false
            onToggled: root.setNight({
                always: checked
            })
        }

        SelectRow {
            visible: root.sunsetInstalled && !(root.night.always ?? false)
            label: Tr.tr("Turns on at")
            menuOnTop: true
            menuItems: fromItems.instances
            active: fromItems.instances.find(i => i.value === (root.night.from ?? "20:00")) ?? null
            onSelected: item => root.setNight({
                    from: item.value
                })

            Variants {
                id: fromItems

                model: ["17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"]

                MenuItem {
                    required property string modelData

                    text: modelData
                    value: modelData
                }
            }
        }

        SelectRow {
            visible: root.sunsetInstalled && !(root.night.always ?? false)
            last: true
            label: Tr.tr("Turns off at")
            menuOnTop: true
            menuItems: toItems.instances
            active: toItems.instances.find(i => i.value === (root.night.to ?? "07:00")) ?? null
            onSelected: item => root.setNight({
                    to: item.value
                })

            Variants {
                id: toItems

                model: ["05:00", "06:00", "07:00", "08:00", "09:00", "10:00"]

                MenuItem {
                    required property string modelData

                    text: modelData
                    value: modelData
                }
            }
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Connections {
            function onRawEvent(event: var): void {
                if (["monitoradded", "monitorremoved", "configreloaded"].includes(event.name))
                    refreshTimer.restart();
            }

            target: Hyprland
        }

        Timer {
            id: refreshTimer

            interval: 600
            onTriggered: root.refresh()
        }

        Timer {
            id: countdownTimer

            interval: 1000
            repeat: true
            onTriggered: {
                root.countdown--;
                if (root.countdown <= 0)
                    root.revert();
            }
        }

        Process {
            id: monitorsProc

            command: ["hyprctl", "-j", "monitors", "all"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.monitors = JSON.parse(text).filter(m => !m.name.startsWith("HEADLESS"));
                    } catch (e) {}
                }
            }
        }

        Process {
            id: whichSunset

            running: true
            command: ["sh", "-c", "command -v hyprsunset"]
            onExited: code => root.sunsetInstalled = code === 0
        }

        // After the install terminal: look again for a while
        Timer {
            id: installCheck

            interval: 5000
            repeat: true
            property int tries
            onTriggered: {
                whichSunset.running = true;
                if (root.sunsetInstalled || ++tries > 60)
                    stop();
            }
        }

        FileView {
            id: sunsetFile

            path: root.sunsetConf
            printErrors: false
            blockLoading: false
        }
    }
}
