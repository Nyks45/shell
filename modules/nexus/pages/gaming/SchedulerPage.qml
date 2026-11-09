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

// The CPU scheduler (scx-manager's job): the kernel's own one, or a sched-ext
// one started by scx_loader at boot (/etc/scx_loader/config.toml) with a mode;
// ananicy-cpp (process priorities by rules). Descriptions from the schedulers'
// own READMEs (sched-ext/scx); none is officially "the" gaming one.
PageBase {
    id: root

    property var scx: null
    readonly property string what: Tr.tr("Change the CPU scheduler")
    readonly property bool busy: Admin.jobs.some(j => j.what === root.what)
    // The one running: "running lavd in Gaming mode" (scxctl get)
    readonly property string running: {
        const m = (scx?.current ?? "").match(/running\s+(\S+)(?:\s+in\s+(\S+)\s+mode)?/i);
        return m ? (m[1].startsWith("scx_") ? m[1] : `scx_${m[1]}`) : "";
    }
    readonly property string runningMode: ((scx?.current ?? "").match(/in\s+(\S+)\s+mode/i) ?? [])[1] ?? ""
    readonly property string chosen: scx?.loader ? (running || scx?.config?.default_sched || "") : ""
    readonly property string mode: runningMode || scx?.config?.default_mode || "Auto"
    readonly property var described: ({
            scx_lavd: Tr.tr("Made for gaming: keeps frame times steady when the processor is busy (latency-aware)"),
            scx_bpfland: Tr.tr("Prefers interactive work (games, the desktop) over background jobs"),
            scx_flash: Tr.tr("Fair and predictable timing; good for audio and games"),
            scx_cosmos: Tr.tr("Light and general-purpose; keeps tasks on the same cores (cache-friendly)"),
            scx_pandemonium: Tr.tr("Adapts to what runs: interactive or throughput"),
            scx_p2dq: Tr.tr("General-purpose, good for many cores and mixed work"),
            scx_rusty: Tr.tr("Balances load across cores; for heavy multi-core work"),
            scx_cake: Tr.tr("Gaming-focused (experimental)"),
            scx_beerland: Tr.tr("Keeps tasks near their cache; general-purpose"),
            scx_tickless: Tr.tr("Fewer timer interrupts; for servers and power saving")
        })
    // The rest are examples or for testing (sched-ext's own words)
    readonly property var order: ["scx_lavd", "scx_bpfland", "scx_flash", "scx_cosmos", "scx_pandemonium", "scx_p2dq", "scx_rusty", "scx_cake", "scx_beerland", "scx_tickless"]
    readonly property var modes: [["Auto", Tr.tr("Automatic")], ["Gaming", Tr.tr("Gaming")], ["LowLatency", Tr.tr("Low latency")], ["PowerSave", Tr.tr("Power saving")], ["Server", Tr.tr("Server")]]

    function load(): void {
        if (!proc.running)
            proc.running = true;
    }

    function pick(sched: string, mode: string): void {
        Admin.run("scx", sched ? [sched, mode] : ["off"], root.what, () => root.load());
    }

    title: Tr.tr("Scheduler")

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.scx !== null
            text: root.busy ? Tr.tr("Changing…") : root.scx?.kernelState === "unsupported" ? Tr.tr("This kernel has no sched-ext: only its own scheduler") : root.running ? Tr.tr("Running: %1 (%2 mode); started again at boot").arg(root.running.replace("scx_", "")).arg(root.mode) : Tr.tr("Running: the kernel's own scheduler (EEVDF)")
            wrapMode: Text.WordWrap
            color: root.running ? Colours.palette.m3primary : Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            first: true
            text: Tr.tr("Scheduler")
        }

        RowButton {
            Layout.fillWidth: true
            visible: root.scx !== null
            disabled: root.busy
            icon: !root.chosen ? "radio_button_checked" : "radio_button_unchecked"
            text: Tr.tr("The kernel's own (EEVDF)")
            subtext: Tr.tr("Good for most use; nothing extra runs")
            onClicked: if (root.chosen)
                root.pick("", "")
        }

        Repeater {
            model: root.scx && root.scx.kernelState !== "unsupported" ? root.order.filter(s => root.scx.available.includes(s)) : []

            RowButton {
                required property string modelData

                Layout.fillWidth: true
                disabled: root.busy
                icon: root.chosen === modelData ? "radio_button_checked" : "radio_button_unchecked"
                text: modelData.replace("scx_", "")
                subtext: root.described[modelData]
                onClicked: if (root.chosen !== modelData)
                    root.pick(modelData, root.mode)
            }
        }

        SectionHeader {
            visible: !!root.chosen
            text: Tr.tr("Mode")
        }

        Flow {
            Layout.fillWidth: true
            visible: !!root.chosen
            spacing: Tokens.spacing.small

            Repeater {
                model: root.modes

                TextButton {
                    required property var modelData

                    enabled: !root.busy
                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.mode === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.pick(root.chosen, modelData[0])
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.chosen
            text: Tr.tr("\"Performance mode while it runs\" (game-performance, in Games) switches to Gaming mode for that game only.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            text: Tr.tr("Priorities")
        }

        ToggleRow {
            visible: root.scx !== null
            text: Tr.tr("Automatic priorities (ananicy-cpp)")
            subtext: Tr.tr("Gives known apps and games higher or lower priority by rules. Turn off if a game stutters with a scheduler above, and don't use it together with GameMode")
            checked: !!root.scx?.ananicy
            onToggled: Admin.run("ananicy", [checked ? "on" : "off"], checked ? Tr.tr("Turn on automatic priorities") : Tr.tr("Turn off automatic priorities"), () => root.load())
        }

        Process {
            id: proc

            command: [`${Paths.libdir}/caelestia-gaming`, "scx"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.scx = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}
