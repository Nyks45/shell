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
    property var mfg: null
    readonly property var values: env?.values ?? {}
    property var wrappers: ["game-performance"]
    property bool changed
    readonly property string mfgFetchWhat: Tr.tr("Download MFG Unlocker")
    readonly property bool mfgFetching: Admin.jobs.some(j => j.what === mfgFetchWhat)
    readonly property var mfgModes: [["follow", Tr.tr("Follow game")], ["2", "2x"], ["3", "3x"], ["4", "4x"]]

    // [key, title, what it does / catch, "on" value, default-on (the key turns it off)]
    readonly property var nvidiaOptions: [["NVPRESENT_ENABLE_SMOOTH_MOTION", Tr.tr("Smooth Motion"), Tr.tr("The driver adds generated frames (RTX 40 and newer; 64-bit DX11/DX12/Vulkan games). A little more input lag, artefacts in fast motion; not with DLSS frame generation; use the game's own frame cap"), "1"], ["DXVK_NVAPI_VKREFLEX", Tr.tr("NVIDIA Reflex"), Tr.tr("Lower input lag in games that support Reflex"), "1"], ["PROTON_DLSS_UPGRADE", Tr.tr("Newest DLSS"), Tr.tr("Games using DLSS get its newest version (downloaded once)"), "1"], ["PROTON_DLSS_INDICATOR", Tr.tr("DLSS indicator"), Tr.tr("Shows which DLSS version and preset a game uses (bottom left)"), "1"], ["PROTON_NVIDIA_LIBS", Tr.tr("CUDA and PhysX for games"), Tr.tr("For games using PhysX, CUDA or NVENC; only when a game needs it"), "1"], ["__GL_THREADED_OPTIMIZATIONS", Tr.tr("Threaded optimisations (OpenGL)"), Tr.tr("Can raise frame rates in OpenGL games; some run worse"), "1"], ["__GL_SHARPEN_ENABLE", Tr.tr("Image sharpening"), Tr.tr("The driver sharpens every OpenGL and Vulkan game"), "1"]]
    readonly property var protonOptions: [["DXVK_HDR", Tr.tr("HDR"), Tr.tr("HDR in games that support it (an HDR monitor with HDR turned on)"), "1"], ["PROTON_NO_NTSYNC", Tr.tr("NTSync"), Tr.tr("Faster thread syncing (the kernel's ntsync); turn off if a game misbehaves"), "1", true], ["PROTON_USE_PIPEWIRE", Tr.tr("PipeWire audio"), Tr.tr("Games talk to PipeWire directly; off: through PulseAudio"), "0", true], ["PROTON_ENABLE_WAYLAND", Tr.tr("Native Wayland (experimental)"), Tr.tr("Games run as Wayland windows instead of through XWayland; some launchers show a white window"), "1"], ["PROTON_LOCAL_SHADER_CACHE", Tr.tr("Shader cache per game"), Tr.tr("Keeps each game's compiled shaders, also with Steam's pre-caching off"), "1"], ["PROTON_PREFER_SDL", Tr.tr("SDL for controllers"), Tr.tr("Try this when a controller isn't detected or misbehaves"), "1"], ["PROTON_DXVK_LOWLATENCY", Tr.tr("Low-latency DXVK"), Tr.tr("A DXVK build with better frame pacing (DX9-11 games)"), "1"], ["PROTON_LOG", Tr.tr("Proton logs"), Tr.tr("Writes a log per game (~/steam-<id>.log) for troubleshooting; off normally"), "1"]]
    readonly property var cacheSizes: [["", Tr.tr("Driver default")], ["4000000000", "4 GB"], ["12000000000", "12 GB"], ["20000000000", "20 GB"]]
    readonly property var wrapperNames: [["game-performance", Tr.tr("Performance mode while it runs")], ["mangohud", Tr.tr("Overlay")], ["dlss-swapper", Tr.tr("Latest DLSS preset")], ["gamescope", Tr.tr("Gamescope")]]
    readonly property string launchLine: [...wrappers.filter(w => w !== "gamescope"), ...(wrappers.includes("gamescope") ? ["gamescope", "--"] : []), "%command%"].join(" ")

    function load(): void {
        if (!proc.running)
            proc.running = true;
        if (!mfgProc.running)
            mfgProc.running = true;
        Games.check();
    }

    function setVar(key: string, value: string): void {
        changed = true;
        Admin.exec([`${Paths.libdir}/caelestia-gaming`, "env-set", key, value], Tr.tr("Change a game option"), () => root.load());
    }

    function isOn(o: var): bool {
        const v = values[o[0]];
        return o[4] ? v === undefined || v !== o[3] : v === o[3];
    }

    title: Tr.tr("Game options")

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
            text: Tr.tr("DLSS Multi Frame Generation (MFG Unlocker)")
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: mfgHeaderL.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: mfgHeaderL

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.mfg?.tag ? Tr.tr("MFG Unlocker %1").arg(root.mfg.tag) : Tr.tr("MFG Unlocker")
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.mfg?.tag ? Tr.tr("Press Backspace in-game for its menu. Only for games that already have DLSS Frame Generation; never use with anti-cheat.") : Tr.tr("Not downloaded yet — unlocks 3x/4x frame generation in games with DLSS FG (never use with anti-cheat).")
                        wrapMode: Text.WordWrap
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                TextButton {
                    enabled: !root.mfgFetching
                    text: root.mfgFetching ? Tr.tr("Downloading…") : root.mfg?.tag ? Tr.tr("Update") : Tr.tr("Download")
                    type: root.mfg?.tag ? TextButton.Tonal : TextButton.Filled
                    onClicked: Admin.exec([`${Paths.libdir}/caelestia-gaming`, "mfg-fetch"], root.mfgFetchWhat, () => root.load())
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.mfg?.tag
            spacing: Tokens.spacing.small

            Repeater {
                model: root.mfgModes

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: (root.mfg?.mode ?? "follow") === modelData[0]
                    type: TextButton.Tonal
                    onClicked: Admin.exec([`${Paths.libdir}/caelestia-gaming`, "mfg-mode", modelData[0]], Tr.tr("Set MFG Unlocker multiplier"), () => root.load())
                }
            }
        }

        Repeater {
            model: root.mfg?.games ?? []

            ConnectedRect {
                id: mfgGame

                required property var modelData
                readonly property bool hasAnticheat: (modelData.anticheat ?? []).length > 0
                readonly property bool launcherBlocked: Games.blocked(modelData.launcher)
                readonly property string setWhat: modelData.installed ? Tr.tr("Remove MFG Unlocker from %1").arg(modelData.title) : Tr.tr("Install MFG Unlocker in %1").arg(modelData.title)
                readonly property bool busy: Admin.jobs.some(j => j.what === mfgGame.setWhat)

                Layout.fillWidth: true
                implicitHeight: mfgGameL.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: mfgGameL

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: mfgGame.modelData.title
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (mfgGame.hasAnticheat)
                                    return Tr.tr("Anti-cheat detected (%1): blocked for safety").arg(mfgGame.modelData.anticheat.join(", "));
                                const parts = [Games.launcherNames[mfgGame.modelData.launcher] ?? mfgGame.modelData.launcher];
                                if (mfgGame.modelData.fgVersion)
                                    parts.push(`DLSS FG ${mfgGame.modelData.fgVersion}`);
                                if (mfgGame.modelData.installed && mfgGame.modelData.name)
                                    parts.push(Tr.tr("Using %1").arg(mfgGame.modelData.name));
                                if (mfgGame.launcherBlocked)
                                    parts.push(Tr.tr("close %1 first").arg(Games.launcherNames[mfgGame.modelData.launcher] ?? mfgGame.modelData.launcher));
                                return parts.join(" · ");
                            }
                            wrapMode: Text.WordWrap
                            color: mfgGame.hasAnticheat || mfgGame.launcherBlocked ? Colours.palette.m3error : mfgGame.modelData.installed ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }

                    TextButton {
                        enabled: !!root.mfg?.tag && !mfgGame.hasAnticheat && !mfgGame.launcherBlocked && !mfgGame.busy
                        text: mfgGame.busy ? Tr.tr("Working…") : mfgGame.modelData.installed ? Tr.tr("Remove") : Tr.tr("Install")
                        type: mfgGame.modelData.installed ? TextButton.Tonal : TextButton.Filled
                        onClicked: Admin.exec([`${Paths.libdir}/caelestia-gaming`, "mfg-set", mfgGame.modelData.key, mfgGame.modelData.installed ? "off" : "on"], mfgGame.setWhat, () => {
                            root.load();
                            Games.load();
                        })
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !!root.mfg && (root.mfg.games ?? []).length === 0
            text: Tr.tr("No installed games with DLSS Frame Generation found.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
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

        Process {
            id: mfgProc

            command: [`${Paths.libdir}/caelestia-gaming`, "mfg"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.mfg = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }
    }
}
