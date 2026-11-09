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

// Options for every game (Proton, DXVK and the NVIDIA driver read them when a
// game starts): kept in the environment.d gaming file (caelestia-gaming env),
// read at login. Each says what it does, its catch and what it needs (NVIDIA
// README 620, proton-cachyos README, CachyOS wiki). For one game only: the
// launch options line built below, to paste into Steam.
PageBase {
    id: root

    property var env: null
    readonly property var values: env?.values ?? {}
    property var wrappers: ["game-performance"]
    property bool changed

    // [key, title, what it does / catch, "on" value, default-on (the key turns it off)]
    readonly property var nvidiaOptions: [["NVPRESENT_ENABLE_SMOOTH_MOTION", Tr.tr("Smooth Motion"), Tr.tr("The driver adds generated frames (RTX 40 and newer; 64-bit DX11/DX12/Vulkan games). A little more input lag, artefacts in fast motion; not with DLSS frame generation; use the game's own frame cap"), "1"], ["DXVK_NVAPI_VKREFLEX", Tr.tr("NVIDIA Reflex"), Tr.tr("Lower input lag in games that support Reflex"), "1"], ["PROTON_DLSS_UPGRADE", Tr.tr("Newest DLSS"), Tr.tr("Games using DLSS get its newest version (downloaded once)"), "1"], ["PROTON_DLSS_INDICATOR", Tr.tr("DLSS indicator"), Tr.tr("Shows which DLSS version and preset a game uses (bottom left)"), "1"], ["PROTON_NVIDIA_LIBS", Tr.tr("CUDA and PhysX for games"), Tr.tr("For games using PhysX, CUDA or NVENC; only when a game needs it"), "1"], ["__GL_THREADED_OPTIMIZATIONS", Tr.tr("Threaded optimisations (OpenGL)"), Tr.tr("Can raise frame rates in OpenGL games; some run worse"), "1"], ["__GL_SHARPEN_ENABLE", Tr.tr("Image sharpening"), Tr.tr("The driver sharpens every OpenGL and Vulkan game"), "1"]]
    readonly property var protonOptions: [["DXVK_HDR", Tr.tr("HDR"), Tr.tr("HDR in games that support it (an HDR monitor with HDR turned on)"), "1"], ["PROTON_NO_NTSYNC", Tr.tr("NTSync"), Tr.tr("Faster thread syncing (the kernel's ntsync); turn off if a game misbehaves"), "1", true], ["PROTON_USE_PIPEWIRE", Tr.tr("PipeWire audio"), Tr.tr("Games talk to PipeWire directly; off: through PulseAudio"), "0", true], ["PROTON_ENABLE_WAYLAND", Tr.tr("Native Wayland (experimental)"), Tr.tr("Games run as Wayland windows instead of through XWayland; some launchers show a white window"), "1"], ["PROTON_LOCAL_SHADER_CACHE", Tr.tr("Shader cache per game"), Tr.tr("Keeps each game's compiled shaders, also with Steam's pre-caching off"), "1"], ["PROTON_PREFER_SDL", Tr.tr("SDL for controllers"), Tr.tr("Try this when a controller isn't detected or misbehaves"), "1"], ["PROTON_DXVK_LOWLATENCY", Tr.tr("Low-latency DXVK"), Tr.tr("A DXVK build with better frame pacing (DX9-11 games)"), "1"], ["PROTON_LOG", Tr.tr("Proton logs"), Tr.tr("Writes a log per game (~/steam-<id>.log) for troubleshooting; off normally"), "1"]]
    readonly property var cacheSizes: [["", Tr.tr("Driver default")], ["4000000000", "4 GB"], ["12000000000", "12 GB"], ["20000000000", "20 GB"]]
    readonly property var wrapperNames: [["game-performance", Tr.tr("Performance mode while it runs")], ["mangohud", Tr.tr("Overlay")], ["dlss-swapper", Tr.tr("Latest DLSS preset")], ["gamescope", Tr.tr("Gamescope")]]
    readonly property string launchLine: [...wrappers.filter(w => w !== "gamescope"), ...(wrappers.includes("gamescope") ? ["gamescope", "--"] : []), "%command%"].join(" ")

    function load(): void {
        proc.running = true;
    }

    function setVar(key: string, value: string): void {
        changed = true;
        Admin.exec([`${Paths.libdir}/caelestia-gaming`, "env-set", key, value], Tr.tr("Change a game option"), () => root.load());
    }

    function isOn(o: var): bool {
        const v = values[o[0]];
        return o[4] ? v === undefined || v !== o[3] : v === o[3];
    }

    title: Tr.tr("Games")

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
            text: root.changed ? Tr.tr("Changed: games started after you log in again use it.") : Tr.tr("For every game; games started after you log in again use a change. Kept in %1.").arg(Paths.shortenHome(root.env?.file ?? ""))
            wrapMode: Text.WordWrap
            color: root.changed ? Colours.palette.m3primary : Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            first: true
            text: "NVIDIA"
        }

        Repeater {
            model: root.env ? root.nvidiaOptions : []

            ToggleRow {
                required property var modelData

                text: modelData[1]
                subtext: modelData[2]
                checked: root.isOn(modelData)
                onToggled: root.setVar(modelData[0], checked === !modelData[4] ? modelData[3] : "--unset")
            }
        }

        StepperRow {
            visible: root.values.__GL_SHARPEN_ENABLE === "1"
            label: Tr.tr("Sharpening strength")
            subtext: Tr.tr("Percent (default 50)")
            from: 0
            to: 100
            stepSize: 5
            value: parseInt(root.values.__GL_SHARPEN_VALUE ?? "50")
            onMoved: v => root.setVar("__GL_SHARPEN_VALUE", String(v))
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Shader cache size (compiled shaders kept between runs: less stutter)")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.cacheSizes

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: (root.values.__GL_SHADER_DISK_CACHE_SIZE ?? "") === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.setVar("__GL_SHADER_DISK_CACHE_SIZE", modelData[0] || "--unset")
                }
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Never clean the shader cache")
            subtext: Tr.tr("The driver doesn't shrink it when it grows past the size")
            checked: root.values.__GL_SHADER_DISK_CACHE_SKIP_CLEANUP === "1"
            onToggled: root.setVar("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", checked ? "1" : "--unset")
        }

        SectionHeader {
            text: "Proton"
        }

        Repeater {
            model: root.env ? root.protonOptions : []

            ToggleRow {
                required property var modelData

                text: modelData[1]
                subtext: modelData[2]
                checked: root.isOn(modelData)
                onToggled: root.setVar(modelData[0], checked === !modelData[4] ? modelData[3] : "--unset")
            }
        }

        // One game: the launch options line
        SectionHeader {
            text: Tr.tr("For one game (Steam launch options)")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.wrapperNames

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.wrappers.includes(modelData[0])
                    type: TextButton.Tonal
                    onClicked: root.wrappers = checked ? root.wrappers.filter(w => w !== modelData[0]) : [...root.wrappers, modelData[0]]
                }
            }
        }

        RowButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            icon: "content_copy"
            text: root.launchLine
            subtext: Tr.tr("Copy, then in Steam: the game › Properties › Launch options")
            onClicked: Quickshell.execDetached(["wl-copy", root.launchLine])
        }

        Process {
            id: proc

            command: [`${Paths.libdir}/caelestia-gaming`, "env"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.env = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}
