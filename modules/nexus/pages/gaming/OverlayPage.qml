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

// The in-game overlay (MangoHud; Goverlay's job): what it shows, where, how
// big, its background, a frame limit; a preview drawn like MangoHud draws it
// (its default colours and layout) over the wallpaper. Saved at once to
// ~/.config/MangoHud/MangoHud.conf (options added by hand are kept).
PageBase {
    id: root

    property var opts: null
    property var envValues: ({})
    readonly property string helper: `${Paths.libdir}/caelestia-gaming`
    // Shown by MangoHud unless turned off
    readonly property var defaultOn: ["fps", "frame_timing", "cpu_stats", "gpu_stats"]
    readonly property var items: [["fps", Tr.tr("Frame rate")], ["frametime", Tr.tr("Frame time")], ["frame_timing", Tr.tr("Frame time graph")], ["gpu_stats", Tr.tr("Graphics card load")], ["gpu_temp", Tr.tr("Graphics card temperature")], ["gpu_power", Tr.tr("Graphics card power")], ["gpu_core_clock", Tr.tr("Graphics card clock")], ["gpu_fan", Tr.tr("Graphics card fan")], ["vram", Tr.tr("Video memory")], ["cpu_stats", Tr.tr("Processor load")], ["cpu_temp", Tr.tr("Processor temperature")], ["cpu_power", Tr.tr("Processor power")], ["ram", Tr.tr("Memory")], ["gpu_name", Tr.tr("Graphics card name")], ["time", Tr.tr("Clock")], ["show_fps_limit", Tr.tr("Frame limit")]]
    readonly property var positions: [["top-left", Tr.tr("Top left")], ["top-center", Tr.tr("Top centre")], ["top-right", Tr.tr("Top right")], ["middle-left", Tr.tr("Left")], ["middle-right", Tr.tr("Right")], ["bottom-left", Tr.tr("Bottom left")], ["bottom-center", Tr.tr("Bottom centre")], ["bottom-right", Tr.tr("Bottom right")]]
    readonly property var limits: [["", Tr.tr("No limit")], ["60", "60"], ["120", "120"], ["144", "144"], ["165", "165"], ["240", "240"]]

    function on(key: string): bool {
        const v = opts?.[key];
        return defaultOn.includes(key) ? v !== false : v === true || (v !== undefined && v !== false && v !== "0");
    }

    function value(key: string, fallback: string): string {
        const v = opts?.[key];
        return typeof v === "string" ? v : fallback;
    }

    function save(change: var): void {
        const o = Object.assign({}, opts ?? {});
        change(o);
        opts = o;
        Admin.exec([helper, "mangohud-set"], Tr.tr("Change the overlay"), null, JSON.stringify(o));
    }

    title: Tr.tr("Overlay")

    Component.onCompleted: {
        loadProc.running = true;
        envProc.running = true;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // The preview: the overlay over the wallpaper, where it will be
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: width * 9 / 16
            radius: Tokens.rounding.large
            clip: true
            color: "black"

            Image {
                anchors.fill: parent
                source: LiveStartFrame.frame ? `file://${LiveStartFrame.frame}` : Wallpapers.actualCurrent ? `file://${Wallpapers.actualCurrent}` : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 960
            }

            Rectangle {
                id: hud

                // About twice as large as on a 1440p screen (readable here)
                readonly property real k: parent.width / 1100
                readonly property real fs: parseInt(root.value("font_size", "24")) * k
                readonly property string pos: root.value("position", "top-left")
                readonly property bool horiz: root.on("horizontal")

                x: pos.endsWith("left") ? 8 : pos.endsWith("right") ? parent.width - width - 8 : (parent.width - width) / 2
                y: pos.startsWith("top") ? 8 : pos.startsWith("bottom") ? parent.height - height - 8 : (parent.height - height) / 2
                width: content.implicitWidth + fs
                height: content.implicitHeight + fs * 0.6
                radius: root.on("round_corners") ? fs * 0.5 : 0
                color: Qt.rgba(0.008, 0.008, 0.008, parseFloat(root.value("background_alpha", "0.5")))

                GridLayout {
                    id: content

                    anchors.centerIn: parent
                    columns: hud.horiz ? 99 : 3
                    rowSpacing: hud.fs * 0.15
                    columnSpacing: hud.fs * 0.5

                    component Cell: Text {
                        font.pixelSize: hud.fs
                        font.bold: true
                        color: "white"
                    }

                    Cell {
                        visible: root.on("gpu_name")
                        Layout.columnSpan: hud.horiz ? 1 : 3
                        text: "RTX 4070 Ti SUPER"
                        color: "#2E9762"
                    }

                    Cell {
                        visible: root.on("gpu_stats") || root.on("gpu_temp") || root.on("gpu_power") || root.on("gpu_core_clock") || root.on("gpu_fan")
                        text: "GPU"
                        color: "#2E9762"
                    }
                    Cell {
                        visible: root.on("gpu_stats") || root.on("gpu_temp") || root.on("gpu_power") || root.on("gpu_core_clock") || root.on("gpu_fan")
                        text: [root.on("gpu_stats") ? "97%" : "", root.on("gpu_temp") ? "64°C" : "", root.on("gpu_fan") ? "41%" : ""].filter(s => s).join("  ")
                    }
                    Cell {
                        visible: root.on("gpu_stats") || root.on("gpu_temp") || root.on("gpu_power") || root.on("gpu_core_clock") || root.on("gpu_fan")
                        text: [root.on("gpu_power") ? "268W" : "", root.on("gpu_core_clock") ? "2790MHz" : ""].filter(s => s).join("  ")
                    }

                    Cell {
                        visible: root.on("cpu_stats") || root.on("cpu_temp") || root.on("cpu_power")
                        text: "CPU"
                        color: "#2E97CB"
                    }
                    Cell {
                        visible: root.on("cpu_stats") || root.on("cpu_temp") || root.on("cpu_power")
                        text: [root.on("cpu_stats") ? "38%" : "", root.on("cpu_temp") ? "71°C" : ""].filter(s => s).join("  ")
                    }
                    Cell {
                        visible: root.on("cpu_stats") || root.on("cpu_temp") || root.on("cpu_power")
                        text: root.on("cpu_power") ? "62W" : ""
                    }

                    Cell {
                        visible: root.on("vram")
                        text: "VRAM"
                        color: "#AD64C1"
                    }
                    Cell {
                        visible: root.on("vram")
                        text: "9.4 GiB"
                    }
                    Cell {
                        visible: root.on("vram")
                        text: ""
                    }

                    Cell {
                        visible: root.on("ram")
                        text: "RAM"
                        color: "#C26693"
                    }
                    Cell {
                        visible: root.on("ram")
                        text: "11.2 GiB"
                    }
                    Cell {
                        visible: root.on("ram")
                        text: ""
                    }

                    Cell {
                        visible: root.on("fps") || root.on("frametime")
                        text: "DX12"
                        color: "#EB5B5B"
                    }
                    Cell {
                        visible: root.on("fps") || root.on("frametime")
                        text: [root.on("fps") ? "144 FPS" : "", root.on("frametime") ? "6.9ms" : ""].filter(s => s).join("  ")
                    }
                    Cell {
                        visible: root.on("fps") || root.on("frametime")
                        text: root.on("show_fps_limit") && root.value("fps_limit", "") ? `/ ${root.value("fps_limit", "")}` : ""
                    }

                    Cell {
                        visible: root.on("time")
                        Layout.columnSpan: hud.horiz ? 1 : 3
                        text: Qt.formatTime(new Date(), "hh:mm:ss")
                    }

                    // The frame time graph
                    Canvas {
                        visible: root.on("frame_timing")
                        Layout.columnSpan: hud.horiz ? 1 : 3
                        Layout.fillWidth: !hud.horiz
                        implicitWidth: hud.fs * 8
                        implicitHeight: hud.fs * 1.6
                        onPaint: {
                            const c = getContext("2d");
                            c.clearRect(0, 0, width, height);
                            c.strokeStyle = "#00FF00";
                            c.lineWidth = Math.max(1, hud.fs / 12);
                            c.beginPath();
                            for (let i = 0; i <= 40; i++) {
                                const y = height * (0.55 + 0.25 * Math.sin(i * 1.7) * Math.cos(i * 0.6) + (i === 27 ? -0.4 : 0));
                                const x = width * i / 40;
                                if (i === 0)
                                    c.moveTo(x, y);
                                else
                                    c.lineTo(x, y);
                            }
                            c.stroke();
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Shift (right) + F12 shows or hides it in a game.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            text: Tr.tr("Showing")
        }

        Repeater {
            model: root.opts ? root.items : []

            ToggleRow {
                required property var modelData

                text: modelData[1]
                checked: root.on(modelData[0])
                onToggled: root.save(o => o[modelData[0]] = checked)
            }
        }

        SectionHeader {
            text: Tr.tr("Where and how")
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            Repeater {
                model: root.positions

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.value("position", "top-left") === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.save(o => o.position = modelData[0])
                }
            }
        }

        StepperRow {
            label: Tr.tr("Text size")
            from: 12
            to: 48
            stepSize: 2
            value: parseInt(root.value("font_size", "24"))
            onMoved: v => root.save(o => o.font_size = String(v))
        }

        StepperRow {
            label: Tr.tr("Background")
            subtext: Tr.tr("Percent of opacity")
            from: 0
            to: 100
            stepSize: 10
            value: Math.round(parseFloat(root.value("background_alpha", "0.5")) * 100)
            onMoved: v => root.save(o => o.background_alpha = (v / 100).toFixed(1))
        }

        ToggleRow {
            text: Tr.tr("In one line")
            checked: root.on("horizontal")
            onToggled: root.save(o => o.horizontal = checked)
        }

        ToggleRow {
            text: Tr.tr("Rounded corners")
            checked: root.on("round_corners")
            onToggled: root.save(o => o.round_corners = checked ? "10" : false)
        }

        SectionHeader {
            text: Tr.tr("Frame limit")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.limits

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.value("fps_limit", "") === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.save(o => o.fps_limit = modelData[0] || false)
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Games")
        }

        ToggleRow {
            text: Tr.tr("In every Vulkan game")
            subtext: Tr.tr("Without adding it per game; other Vulkan apps show it too (after logging in again). Per game: \"mangohud %command%\" in Games")
            checked: root.envValues.MANGOHUD === "1"
            onToggled: Admin.exec([root.helper, "env-set", "MANGOHUD", checked ? "1" : "--unset"], Tr.tr("Change a game option"), () => envProc.running = true)
        }

        Process {
            id: loadProc

            command: [root.helper, "mangohud"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.opts = JSON.parse(text).options ?? {};
                    } catch (e) {
                        root.opts = {};
                    }
                }
            }
        }

        Process {
            id: envProc

            command: [root.helper, "env"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.envValues = JSON.parse(text).values ?? {};
                    } catch (e) {}
                }
            }
        }
    }
}
