pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

// Live wallpaper settings (all live wallpapers): playback, folders and the
// renderer's version. Moved out of the wallpapers page so the list comes first.
PageBase {
    id: root

    readonly property var monitors: Hypr.monitors.values.map(m => m.name)
    property var recordingSources: []
    property var discoveredMediaPlayers: []
    readonly property var ignoredMediaPlayers: LiveWallpaper.setting("ignoredMediaPlayers", [])
    readonly property var mediaPlayers: [...new Set([...discoveredMediaPlayers, ...ignoredMediaPlayers])].sort()
    readonly property var defaultGraphics: graphicsPreset(60, 0, "ultra", "medium", true)

    function graphicsPreset(fps: int, samples: int, bloom: string, lighting: string, reflections: bool): var {
        return {
            fps: fps,
            msaaSamples: samples,
            postProcessing: bloom,
            shadowQuality: lighting,
            volumetricQuality: lighting,
            reflections: reflections,
            textureResolution: "full",
            hdrOutput: false
        };
    }

    property Process recordingProbe: Process {
        running: true
        command: ["pactl", "-f", "json", "list", "sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sources = [{ name: "", description: Tr.tr("Default output monitor") }];
                try {
                    for (const source of JSON.parse(text))
                        if (source.name)
                            sources.push({ name: source.name, description: source.description || source.name });
                } catch (e) {}
                root.recordingSources = sources;
            }
        }
    }

    property Process mediaProbe: Process {
        running: true
        command: ["busctl", "--user", "--no-legend", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const prefix = "org.mpris.MediaPlayer2.";
                root.discoveredMediaPlayers = text.split("\n").map(line => line.trim().split(/\s+/)[0])
                    .filter(name => name.startsWith(prefix))
                    .map(name => name.slice(prefix.length).replace(/\.instance\d+$/, ""));
            }
        }
    }

    component LightingQualityRow: SelectRow {
        required property string settingsKey
        menuItems: [
            MenuItem { text: Tr.tr("Off"); value: "off" },
            MenuItem { text: Tr.tr("Low"); value: "low" },
            MenuItem { text: Tr.tr("Medium"); value: "medium" },
            MenuItem { text: Tr.tr("High"); value: "high" },
            MenuItem { text: Tr.tr("Ultra"); value: "ultra" }
        ]
        active: menuItems.find(i => i.value === LiveWallpaper.setting(settingsKey, "medium")) ?? null
        onSelected: item => LiveWallpaper.set(settingsKey, item.value)
    }

    // The app for a new rule. Rules match the window class as a lowercase
    // substring, so a class guessed from a reverse-DNS desktop id uses its last
    // part (com.discordapp.Discord -> Discord)
    function pickRuleApp(): void {
        appPicker.openPicker({
            header: Tr.tr("Choose an app"),
            includeRunning: true,
            allowCustom: true,
            onPicked: item => {
                newRuleCard.selectedApp = item.classAlt || item.wmClass || item.id;
                newRuleCard.selectedName = item.name;
                newRuleCard.selectedIcon = item.icon;
            }
        });
    }

    function whenText(w: string): string {
        return ({
                running: Tr.tr("is running"),
                focused: Tr.tr("is focused"),
                maximized: Tr.tr("is maximized"),
                fullscreen: Tr.tr("is fullscreen"),
                audio: Tr.tr("is playing media")
            })[w] ?? w;
    }

    function actionText(a: string): string {
        return ({
                pause: Tr.tr("pause"),
                pauseMonitor: Tr.tr("pause on the app’s display"),
                mute: Tr.tr("mute"),
                stop: Tr.tr("stop (free memory)"),
                stopMonitor: Tr.tr("stop on the app’s display"),
                loadWallpaper: Tr.tr("load wallpaper"),
                loadPlaylist: Tr.tr("load playlist"),
                loadProfile: Tr.tr("load display profile"),
                run: Tr.tr("keep running")
            })[a] ?? a;
    }

    title: Tr.tr("Live wallpaper settings")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Performance (all live wallpapers)
        SectionHeader {
            text: Tr.tr("Performance")
        }

        SelectRow {
            label: Tr.tr("Graphics preset")
            menuItems: [
                MenuItem { text: Tr.tr("Low"); value: root.graphicsPreset(10, 0, "off", "low", false) },
                MenuItem { text: Tr.tr("Medium"); value: root.graphicsPreset(15, 0, "normal", "medium", true) },
                MenuItem { text: Tr.tr("High"); value: root.graphicsPreset(25, 2, "normal", "high", true) },
                MenuItem { text: Tr.tr("Ultra"); value: root.graphicsPreset(30, 2, "ultra", "ultra", true) }
            ]
            fallbackText: Tr.tr("Custom")
            active: menuItems.find(i => Object.entries(i.value)
                .every(([key, value]) => LiveWallpaper.setting(key, root.defaultGraphics[key]) === value)) ?? null
            onSelected: item => LiveWallpaper.setGraphicsPreset(item.value)
        }

        SelectRow {
            label: Tr.tr("Anti-aliasing")
            subtext: Tr.tr("Smooth model edges. Higher sample counts use more video memory.")
            menuItems: [
                MenuItem { text: Tr.tr("Off"); value: 0 },
                MenuItem { text: Tr.tr("2× MSAA"); value: 2 },
                MenuItem { text: Tr.tr("4× MSAA"); value: 4 },
                MenuItem { text: Tr.tr("8× MSAA"); value: 8 }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("msaaSamples", 0)) ?? null
            onSelected: item => LiveWallpaper.set("msaaSamples", item.value)
        }

        SelectRow {
            label: Tr.tr("Post-processing")
            subtext: Tr.tr("Bloom and lighting effects (Ultra enables HDR bloom)")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Low (effects off)")
                    value: "off"
                },
                MenuItem {
                    text: Tr.tr("Medium (standard bloom)")
                    value: "normal"
                },
                MenuItem {
                    text: Tr.tr("Ultra (HDR bloom)")
                    value: "ultra"
                }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("postProcessing", "ultra")) ?? null
            onSelected: item => LiveWallpaper.set("postProcessing", item.value)
        }

        ToggleRow {
            text: Tr.tr("HDR display output")
            subtext: Tr.tr("Present Ultra HDR scenes in HDR on supported Wayland outputs")
            enabled: LiveWallpaper.setting("postProcessing", "ultra") === "ultra"
            checked: LiveWallpaper.setting("hdrOutput", false)
            onToggled: LiveWallpaper.set("hdrOutput", checked)
        }

        ToggleRow {
            text: Tr.tr("Reflections")
            checked: LiveWallpaper.setting("reflections", true)
            onToggled: LiveWallpaper.set("reflections", checked)
        }

        LightingQualityRow {
            label: Tr.tr("Shadows")
            settingsKey: "shadowQuality"
        }

        LightingQualityRow {
            label: Tr.tr("Volumetric lighting")
            settingsKey: "volumetricQuality"
        }

        SelectRow {
            label: Tr.tr("Texture resolution")
            menuItems: [
                MenuItem { text: Tr.tr("Full"); value: "full" },
                MenuItem { text: Tr.tr("Half"); value: "half" },
                MenuItem { text: Tr.tr("Automatic"); value: "auto" }
            ]
            subtext: Tr.tr("Half uses smaller stored texture levels. Automatic follows the GPU texture limit.")
            active: menuItems.find(i => i.value === LiveWallpaper.setting("textureResolution", "full")) ?? null
            onSelected: item => LiveWallpaper.set("textureResolution", item.value)
        }

        SelectRow {
            label: Tr.tr("Process priority")
            menuItems: [
                MenuItem { text: Tr.tr("Normal"); value: "normal" },
                MenuItem { text: Tr.tr("Below normal"); value: "belowNormal" }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("processPriority", "normal")) ?? null
            onSelected: item => LiveWallpaper.set("processPriority", item.value)
        }

        SelectRow {
            label: Tr.tr("Frame rate")
            subtext: Tr.tr("Higher is smoother and uses more power")
            menuItems: fpsItems.instances
            active: fpsItems.instances.find(i => i.value === LiveWallpaper.setting("fps", 60)) ?? null
            fallbackText: `${LiveWallpaper.setting("fps", 60)} fps`
            onSelected: item => LiveWallpaper.set("fps", item.value)

            Variants {
                id: fpsItems

                model: {
                    const maxRate = Math.max(60, ...Hypr.monitors.values.map(m => Math.round(m.lastIpcObject?.refreshRate ?? 60)));
                    return [10, 15, 24, 25, 30, 60, 90, 120, 144, 165, 240, 360].filter(f => f <= maxRate);
                }

                MenuItem {
                    required property int modelData

                    text: `${modelData} fps`
                    value: modelData
                }
            }
        }

        SelectRow {
            label: Tr.tr("Video decoding")
            subtext: Tr.tr("Hardware decoding saves CPU on video wallpapers")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Automatic")
                    value: "auto"
                },
                MenuItem {
                    text: Tr.tr("NVIDIA (NVDEC)")
                    value: "nvdec-copy"
                },
                MenuItem { text: Tr.tr("Automatic (safe)"); value: "auto-safe" },
                MenuItem { text: Tr.tr("VA-API"); value: "vaapi" },
                MenuItem { text: Tr.tr("VA-API (copy)"); value: "vaapi-copy" },
                MenuItem { text: Tr.tr("Vulkan"); value: "vulkan" },
                MenuItem { text: Tr.tr("Vulkan (copy)"); value: "vulkan-copy" },
                MenuItem {
                    text: Tr.tr("Software (CPU)")
                    value: "no"
                }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("hwdec", "auto")) ?? null
            onSelected: item => LiveWallpaper.set("hwdec", item.value)
        }

        SelectRow {
            label: Tr.tr("Video loading")
            subtext: Tr.tr("In-memory keeps the active video file in RAM")
            menuItems: [
                MenuItem { text: Tr.tr("From disk"); value: "disk" },
                MenuItem { text: Tr.tr("In-memory"); value: "memory" }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("videoLoading", "disk")) ?? null
            onSelected: item => LiveWallpaper.set("videoLoading", item.value)
        }

        ToggleRow {
            text: Tr.tr("Particles")
            subtext: Tr.tr("Off saves GPU on busy wallpapers")
            checked: !LiveWallpaper.setting("disableParticles", false)
            onToggled: LiveWallpaper.set("disableParticles", !checked)
        }

        ToggleRow {
            text: Tr.tr("Pause when video memory is low")
            subtext: Tr.tr("Pause playback below 64 MiB of free video memory on supported drivers")
            checked: LiveWallpaper.setting("pauseOnLowVram", false)
            onToggled: LiveWallpaper.set("pauseOnLowVram", checked)
        }

        SectionHeader {
            text: Tr.tr("Sound & interaction")
        }

        ToggleRow {
            text: Tr.tr("Sound")
            subtext: Tr.tr("For wallpapers that have it")
            checked: !LiveWallpaper.setting("silent", true)
            onToggled: LiveWallpaper.set("silent", !checked)
        }

        SliderRow {
            visible: !LiveWallpaper.setting("silent", true)
            icon: "volume_up"
            label: Tr.tr("Volume")
            valueLabel: `${LiveWallpaper.setting("volume", 50)}%`
            value: LiveWallpaper.setting("volume", 50) / 100
            onMoved: v => LiveWallpaper.set("volume", Math.round(v * 100))
        }

        Repeater {
            model: root.monitors

            ToggleRow {
                required property string modelData
                text: Tr.tr("Sound on %1").arg(modelData)
                checked: !LiveWallpaper.mutedOutputs.includes(modelData)
                onToggled: {
                    const outputs = checked ? LiveWallpaper.mutedOutputs.filter(name => name !== modelData)
                        : [...LiveWallpaper.mutedOutputs, modelData];
                    if (LiveWallpaper.activeScreens[modelData] || LiveWallpaper.activeScreens["*"])
                        LiveWallpaper.set("mutedOutputs", outputs);
                    else
                        LiveWallpaper.setQuiet("mutedOutputs", outputs);
                }
            }
        }

        ToggleRow {
            text: Tr.tr("React to music")
            subtext: Tr.tr("Audio visualisers in wallpapers follow what's playing")
            checked: LiveWallpaper.setting("audioProcessing", true)
            onToggled: LiveWallpaper.set("audioProcessing", checked)
        }

        SelectRow {
            label: Tr.tr("Audio recording device")
            enabled: LiveWallpaper.setting("audioProcessing", true)
            menuItems: recordingItems.instances
            active: menuItems.find(i => i.value === LiveWallpaper.setting("audioRecordingSource", "")) ?? null
            fallbackText: LiveWallpaper.setting("audioRecordingSource", "") || Tr.tr("Default output monitor")
            onSelected: item => LiveWallpaper.set("audioRecordingSource", item.value)

            Variants {
                id: recordingItems
                model: root.recordingSources
                MenuItem {
                    required property var modelData
                    text: modelData.description
                    value: modelData.name
                }
            }
        }

        ToggleRow {
            text: Tr.tr("Reload when changing output device")
            subtext: Tr.tr("Restart the wallpaper when the default audio output changes")
            checked: LiveWallpaper.setting("reloadOnAudioOutputChange", true)
            onToggled: LiveWallpaper.setQuiet("reloadOnAudioOutputChange", checked)
        }

        SliderRow {
            icon: "mic"
            label: Tr.tr("Recording volume")
            subtext: Tr.tr("Adjust the response to audio. 50 is the original level")
            enabled: LiveWallpaper.setting("audioProcessing", true)
            valueLabel: String(LiveWallpaper.setting("audioRecordingVolume", 50))
            value: LiveWallpaper.setting("audioRecordingVolume", 50) / 200
            onMoved: v => LiveWallpaper.set("audioRecordingVolume", Math.round(v * 200))
        }

        SliderRow {
            icon: "graphic_eq"
            label: Tr.tr("Recording threshold")
            subtext: Tr.tr("Ignore quiet input when reacting to audio")
            enabled: LiveWallpaper.setting("audioProcessing", true)
            valueLabel: Number(LiveWallpaper.setting("audioRecordingThreshold", 0)).toFixed(1)
            value: LiveWallpaper.setting("audioRecordingThreshold", 0) / 10
            onMoved: v => LiveWallpaper.set("audioRecordingThreshold", Math.round(v * 100) / 10)
        }

        ToggleRow {
            text: Tr.tr("Media integration")
            subtext: Tr.tr("Share track information and album artwork with wallpapers")
            checked: LiveWallpaper.setting("mediaIntegration", true)
            onToggled: LiveWallpaper.set("mediaIntegration", checked)
        }

        Repeater {
            model: LiveWallpaper.setting("mediaIntegration", true) ? root.mediaPlayers : []

            ToggleRow {
                required property string modelData
                text: Tr.tr("Ignore %1").arg(modelData)
                checked: root.ignoredMediaPlayers.includes(modelData)
                onToggled: LiveWallpaper.set("ignoredMediaPlayers", checked
                    ? [...root.ignoredMediaPlayers, modelData]
                    : root.ignoredMediaPlayers.filter(player => player !== modelData))
            }
        }

        SelectRow {
            label: Tr.tr("Fit")
            menuOnTop: true
            menuItems: [
                MenuItem {
                    text: Tr.tr("Fill the screen (crop)")
                    value: "fill"
                },
                MenuItem {
                    text: Tr.tr("Fit (keep aspect ratio)")
                    value: "fit"
                },
                MenuItem {
                    text: Tr.tr("Stretch")
                    value: "stretch"
                },
                MenuItem {
                    text: Tr.tr("As the wallpaper says")
                    value: "default"
                }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("scaling", "fill")) ?? null
            onSelected: item => LiveWallpaper.set("scaling", item.value)
        }

        ToggleRow {
            text: Tr.tr("React to the mouse")
            checked: !LiveWallpaper.setting("disableMouse", false)
            onToggled: LiveWallpaper.set("disableMouse", !checked)
        }

        ToggleRow {
            text: Tr.tr("Parallax")
            subtext: Tr.tr("Layers shift as the mouse moves")
            checked: !LiveWallpaper.setting("disableParallax", false)
            onToggled: LiveWallpaper.set("disableParallax", !checked)
        }

        SelectRow {
            label: Tr.tr("Identify displays by")
            menuItems: [
                MenuItem { text: Tr.tr("Connector"); value: "connector" },
                MenuItem { text: Tr.tr("Monitor serial number"); value: "serial" },
                MenuItem { text: Tr.tr("Monitor description"); value: "description" },
                MenuItem { text: Tr.tr("Desktop layout"); value: "layout" }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("monitorIdentification", "connector")) ?? null
            onSelected: item => LiveWallpaper.set("monitorIdentification", item.value)
        }

        // Wallpaper Engine's "Other application ..." playback rules
        SectionHeader {
            text: Tr.tr("When other apps are in use")
        }

        ToggleRow {
            text: Tr.tr("Fullscreen rule only for focused apps")
            visible: LiveWallpaper.playbackRules.fullscreen !== "run"
            checked: LiveWallpaper.setting("pauseOnlyActive", false)
            onToggled: LiveWallpaper.set("pauseOnlyActive", checked)
        }

        // Fullscreen apps that don't pause it
        AppListEditor {
            visible: LiveWallpaper.playbackRules.fullscreen !== "run"
            hostFlickable: root.flickable
            values: LiveWallpaper.setting("pauseIgnore", [])
            addLabel: Tr.tr("Add an app to ignore")
            emptyText: Tr.tr("Every fullscreen app pauses live wallpapers")
            pickerHeader: Tr.tr("Don't pause for app")
            includeRunning: true
            allowCustom: true
            useWmClass: true
            onEdited: v => LiveWallpaper.set("pauseIgnore", v)
        }

        Repeater {
            model: [
                {
                    key: "focused",
                    text: Tr.tr("Another app is focused"),
                    sub: Tr.tr("Applies while an app window has focus")
                },
                {
                    key: "maximized",
                    text: Tr.tr("An app is maximized")
                },
                {
                    key: "fullscreen",
                    text: Tr.tr("An app is fullscreen")
                },
                {
                    key: "audio",
                    text: Tr.tr("Another app plays audio")
                },
                {
                    key: "battery",
                    text: Tr.tr("Running on battery")
                },
                {
                    key: "displayAsleep",
                    text: Tr.tr("Wallpaper displays are asleep")
                }
            ]

            SelectRow {
                required property var modelData
                required property int index

                label: modelData.text
                subtext: modelData.sub ?? ""
                readonly property list<MenuItem> allActions: [
                    MenuItem {
                        text: Tr.tr("Keep running")
                        value: "run"
                    },
                    MenuItem {
                        text: Tr.tr("Mute")
                        value: "mute"
                    },
                    MenuItem {
                        text: Tr.tr("Pause")
                        value: "pause"
                    },
                    MenuItem {
                        text: Tr.tr("Stop (free memory)")
                        value: "stop"
                    },
                    MenuItem {
                        text: Tr.tr("Pause per display")
                        value: "pauseMonitor"
                    },
                    MenuItem {
                        text: Tr.tr("Stop per display")
                        value: "stopMonitor"
                    }
                ]
                menuItems: Array.from(allActions).filter(item => !item.value.endsWith("Monitor") || !["audio", "battery"].includes(modelData.key))
                active: menuItems.find(i => i.value === LiveWallpaper.playbackRules[modelData.key]) ?? null
                onSelected: item => LiveWallpaper.setPlaybackRule(modelData.key, item.value)
            }
        }

        InfoRow {
            icon: LiveWallpaper.ruleAction === "run" ? "play_circle" : LiveWallpaper.ruleAction === "mute" ? "volume_off" : LiveWallpaper.ruleAction === "pause" ? "pause_circle" : "stop_circle"
            label: Tr.tr("Now")
            subtext: LiveWallpaper.ruleReason || Tr.tr("No rule applies")
            value: ({
                    run: Tr.tr("Playing"),
                    mute: Tr.tr("Muted"),
                    pause: Tr.tr("Paused"),
                    stop: Tr.tr("Stopped")
                })[LiveWallpaper.ruleAction] ?? ""
        }

        // App rules: this app running / focused / maximized / fullscreen / playing -> action
        SectionHeader {
            text: Tr.tr("Display profiles")
        }

        TextFieldRow {
            id: profileName

            label: Tr.tr("Profile name")
            subtext: Tr.tr("Save the current wallpapers and playlists for every display")
        }

        NavRow {
            icon: "save"
            text: Tr.tr("Save current display setup")
            enabled: !!profileName.field.text.trim() && Object.keys(LiveWallpaper.screens).length > 0
            onClicked: {
                LiveWallpaper.saveProfile(profileName.field.text);
                profileName.clear();
            }
        }

        Repeater {
            model: LiveWallpaper.profiles

            NavRow {
                required property var modelData

                icon: "delete"
                text: Tr.tr("Delete profile %1").arg(modelData.name)
                onClicked: confirmDialog.ask({
                    header: Tr.tr("Delete profile %1?").arg(modelData.name),
                    confirmLabel: Tr.trCtx("Delete", "button"),
                    onConfirm: () => LiveWallpaper.setQuiet("profiles", LiveWallpaper.profiles.filter(p => p.name !== modelData.name))
                })
            }
        }

        SectionHeader {
            text: Tr.tr("App rules")
        }

        Repeater {
            id: ruleList

            model: LiveWallpaper.appRules

            ConnectedRect {
                id: lwRuleRow

                required property var modelData
                required property int index
                readonly property DesktopEntry desktopEntry: DesktopEntries.heuristicLookup(modelData.app) ?? DesktopEntries.byId(modelData.app)
                readonly property string displayName: desktopEntry ? desktopEntry.name : modelData.app

                Layout.fillWidth: true
                implicitHeight: lwRuleLayout.implicitHeight + Tokens.padding.small * 2

                RowLayout {
                    id: lwRuleLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28

                        ThemedIcon {
                            anchors.fill: parent
                            asynchronous: true
                            monochrome: true
                            visible: !!(lwRuleRow.desktopEntry?.icon)
                            source: lwRuleRow.desktopEntry?.icon ? Quickshell.iconPath(lwRuleRow.desktopEntry.icon, "application-x-executable") : ""
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !(lwRuleRow.desktopEntry?.icon)
                            text: "rule"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: lwRuleRow.displayName
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${root.whenText(lwRuleRow.modelData.when)} → ${root.actionText(lwRuleRow.modelData.action)}${lwRuleRow.modelData.target ? " · " + (LiveWallpaper.wallpapers.find(w => w.path === lwRuleRow.modelData.target)?.title ?? lwRuleRow.modelData.target) : ""}`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: confirmDialog.ask({
                            header: Tr.tr("Delete rule for %1?").arg(lwRuleRow.displayName),
                            body: Tr.tr("This app-specific live wallpaper rule will be removed."),
                            confirmLabel: Tr.trCtx("Delete", "button"),
                            onConfirm: () => LiveWallpaper.setAppRules(LiveWallpaper.appRules.filter((r, i) => i !== lwRuleRow.index))
                        })
                    }
                }
            }
        }

        ConnectedRect {
            id: newRuleCard

            property string selectedApp: ""
            property string selectedName: ""
            property string selectedIcon: ""
            property string target: ""

            Layout.fillWidth: true
            implicitHeight: ruleCol.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: ruleCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    text: Tr.tr("New rule")
                    font: Tokens.font.body.small
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: pickedAppRow.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: root.pickRuleApp()
                    }

                    RowLayout {
                        id: pickedAppRow

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.medium

                        Item {
                            implicitWidth: 24
                            implicitHeight: 24

                            ThemedIcon {
                                anchors.fill: parent
                                asynchronous: true
                                monochrome: true
                                visible: newRuleCard.selectedIcon.length > 0
                                source: newRuleCard.selectedIcon ? Quickshell.iconPath(newRuleCard.selectedIcon, "application-x-executable") : ""
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: newRuleCard.selectedIcon.length === 0
                                text: "apps"
                                color: Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: newRuleCard.selectedApp ? (newRuleCard.selectedName || newRuleCard.selectedApp) : Tr.tr("No app selected")
                            color: newRuleCard.selectedApp ? Colours.palette.m3onSurface : Colours.palette.m3outline
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        TextButton {
                            text: Tr.tr("Pick app")
                            type: TextButton.Tonal
                            onClicked: root.pickRuleApp()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    RuleChoiceButton {
                        id: ruleWhen

                        options: [["running", root.whenText("running")], ["focused", root.whenText("focused")], ["maximized", root.whenText("maximized")], ["fullscreen", root.whenText("fullscreen")], ["audio", root.whenText("audio")]]
                    }

                    StyledText {
                        text: "→"
                    }

                    RuleChoiceButton {
                        id: ruleAction

                        options: [["pause", root.actionText("pause")], ["mute", root.actionText("mute")],
                            ["stop", root.actionText("stop")], ["run", root.actionText("run")],
                            ["pauseMonitor", root.actionText("pauseMonitor")], ["stopMonitor", root.actionText("stopMonitor")],
                            ["loadWallpaper", root.actionText("loadWallpaper")], ["loadPlaylist", root.actionText("loadPlaylist")],
                            ["loadProfile", root.actionText("loadProfile")]]
                        onValueChanged: newRuleCard.target = ""
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: Tr.tr("Add")
                        type: TextButton.Filled
                        disabled: !newRuleCard.selectedApp || (ruleAction.value.startsWith("load") && !newRuleCard.target)
                        onClicked: {
                            LiveWallpaper.setAppRules(LiveWallpaper.appRules.concat([{
                                    app: newRuleCard.selectedApp,
                                    when: ruleWhen.value,
                                    action: ruleAction.value,
                                    target: newRuleCard.target
                                }]));
                            newRuleCard.selectedApp = "";
                            newRuleCard.selectedName = "";
                            newRuleCard.selectedIcon = "";
                            newRuleCard.target = "";
                        }
                    }
                }

                SelectRow {
                    visible: ruleAction.value.startsWith("load")
                    label: Tr.tr("Load")
                    fallbackText: Tr.tr("Choose…")
                    menuItems: ruleTargets.instances
                    active: menuItems.find(item => item.value === newRuleCard.target) ?? null
                    onSelected: item => newRuleCard.target = item.value

                    Variants {
                        id: ruleTargets

                        model: ruleAction.value === "loadWallpaper" ? LiveWallpaper.wallpapers.map(w => [w.title, w.path])
                            : ruleAction.value === "loadPlaylist" ? LiveWallpaper.playlists.map(p => [p.name, p.name])
                            : ruleAction.value === "loadProfile" ? LiveWallpaper.profiles.map(p => [p.name, p.name]) : []

                        MenuItem {
                            required property var modelData

                            text: modelData[0]
                            value: modelData[1]
                        }
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Folders")
        }

        FolderPickerRow {
            label: Tr.tr("Wallpaper Engine folder")
            subtext: LiveWallpaper.setting("assetsDir", "") ? Tr.tr("Custom folder (click Reset to auto-detect)") : Tr.tr("Found automatically: %1").arg(Paths.shortenHome(LiveWallpaper.assetsDetected.replace(/\/assets$/, "")) || Tr.tr("not found"))
            value: LiveWallpaper.setting("assetsDir", "")
            placeholderText: ""
            canReset: true
            onPicked: path => {
                LiveWallpaper.set("assetsDir", path);
                LiveWallpaper.refresh();
            }
            onResetClicked: {
                LiveWallpaper.set("assetsDir", "");
                LiveWallpaper.refresh();
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Every Steam library is searched (also on other drives). Extra folders with wallpapers of your own:")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: LiveWallpaper.setting("extraFolders", [])

            ConnectedRect {
                id: extraFolderRow

                required property string modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: extraRowLayout.implicitHeight + Tokens.padding.small * 2

                RowLayout {
                    id: extraRowLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "folder"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        fill: 1
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Paths.shortenHome(extraFolderRow.modelData)
                        font: Tokens.font.mono.small
                        wrapMode: Text.Wrap
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        onClicked: {
                            const next = [...LiveWallpaper.setting("extraFolders", [])];
                            next.splice(extraFolderRow.index, 1);
                            LiveWallpaper.setQuiet("extraFolders", next);
                            Qt.callLater(() => LiveWallpaper.refresh());
                        }
                    }
                }
            }
        }

        RowButton {
            icon: "create_new_folder"
            text: Tr.tr("Add a wallpaper folder")
            subtext: LiveWallpaper.setting("extraFolders", []).length === 0 ? Tr.tr("No extra folders added") : ""
            onClicked: extraFolderDialog.openAt(Paths.home)
        }

        FileDialog {
            id: extraFolderDialog

            folderMode: true
            title: Tr.tr("Add a wallpaper folder")
            onAccepted: path => {
                const cur = LiveWallpaper.setting("extraFolders", []);
                if (!cur.includes(path)) {
                    LiveWallpaper.setQuiet("extraFolders", [...cur, path]);
                    Qt.callLater(() => LiveWallpaper.refresh());
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Desktop and screensaver")
        }

        ToggleRow {
            text: Tr.tr("Switch desktop colors with the wallpaper")
            subtext: Tr.tr("Update the dynamic color scheme from the selected wallpaper")
            checked: LiveWallpaper.setting("wallpaperColors", true)
            onToggled: LiveWallpaper.set("wallpaperColors", checked)
        }

        ToggleRow {
            text: Tr.tr("Show wallpaper on the lock screen")
            subtext: Tr.tr("Use the saved wallpaper frame when locking the session")
            checked: LiveWallpaper.setting("showLiveOnLock", false)
            onToggled: LiveWallpaper.setQuiet("showLiveOnLock", checked)
        }

        ToggleRow {
            text: Tr.tr("Wallpaper screensaver")
            subtext: Tr.tr("Show wallpaper above open windows while the session is idle")
            checked: LiveWallpaper.setting("screensaverEnabled", false)
            onToggled: LiveWallpaper.setQuiet("screensaverEnabled", checked)
        }

        StepperRow {
            visible: LiveWallpaper.setting("screensaverEnabled", false)
            label: Tr.tr("Start after (minutes)")
            from: 1
            to: 120
            value: LiveWallpaper.setting("screensaverTimeout", 600) / 60
            onMoved: v => LiveWallpaper.setQuiet("screensaverTimeout", v * 60)
        }

        SelectRow {
            visible: LiveWallpaper.setting("screensaverEnabled", false)
            label: Tr.tr("Screensaver wallpaper")
            menuItems: saverChoices.instances
            active: menuItems.find(item => item.value === LiveWallpaper.setting("screensaverWallpaper", "")) ?? null
            onSelected: item => LiveWallpaper.setQuiet("screensaverWallpaper", item.value)

            Variants {
                id: saverChoices

                model: [[Tr.tr("Same as desktop"), ""]].concat(
                    LiveWallpaper.profiles.map(p => [Tr.tr("Profile · %1").arg(p.name), `profile:${p.name}`]),
                    LiveWallpaper.playlists.map(p => [Tr.tr("Playlist · %1").arg(p.name), `playlist:${p.name}`]),
                    LiveWallpaper.wallpapers.map(w => [w.title, w.path]))

                MenuItem {
                    required property var modelData

                    text: modelData[0]
                    value: modelData[1]
                }
            }
        }

        ToggleRow {
            visible: LiveWallpaper.setting("screensaverEnabled", false)
            text: Tr.tr("Play screensaver audio")
            checked: LiveWallpaper.setting("screensaverSound", false)
            onToggled: LiveWallpaper.setQuiet("screensaverSound", checked)
        }

        SectionHeader {
            text: Tr.tr("Wallpaper browser")
        }

        SelectRow {
            label: Tr.tr("Wallpaper switch transition")
            menuItems: transitionChoices.instances
            active: menuItems.find(item => item.value === LiveWallpaper.setting("browseTransition", "none")) ?? null
            onSelected: item => LiveWallpaper.setQuiet("browseTransition", item.value)

            Variants {
                id: transitionChoices

                model: LiveWallpaper.transitionTypes

                MenuItem {
                    required property var modelData

                    text: modelData[1]
                    value: modelData[0]
                }
            }
        }

        StepperRow {
            visible: !["hold", "none"].includes(LiveWallpaper.setting("browseTransition", "none"))
            label: Tr.tr("Transition time (ms)")
            from: 0
            to: 3000
            stepSize: 50
            value: LiveWallpaper.setting("transitionDuration", 350)
            onMoved: v => LiveWallpaper.setQuiet("transitionDuration", v)
        }

        Repeater {
            model: LiveWallpaper.setting("browseTransition", "none") === "random" ? LiveWallpaper.transitionTypes.slice(3) : []

            ToggleRow {
                required property var modelData
                readonly property var pool: LiveWallpaper.setting("transitionPool", LiveWallpaper.transitionTypes.slice(3).map(t => t[0]))

                text: modelData[1]
                checked: pool.includes(modelData[0])
                enabled: !checked || pool.length > 1
                onToggled: LiveWallpaper.setQuiet("transitionPool", checked ? [...pool, modelData[0]] : pool.filter(id => id !== modelData[0]))
            }
        }

        ToggleRow {
            text: Tr.tr("Show live wallpaper in the tray")
            checked: LiveWallpaper.setting("showTrayIcon", false)
            onToggled: LiveWallpaper.setQuiet("showTrayIcon", checked)
        }

        ToggleRow {
            text: Tr.tr("Animate wallpaper previews")
            checked: LiveWallpaper.setting("browserEffects", true)
            onToggled: LiveWallpaper.setQuiet("browserEffects", checked)
        }

        SelectRow {
            label: Tr.tr("Wallpaper browser quality")
            menuItems: [
                MenuItem { text: Tr.tr("Low"); value: "low" },
                MenuItem { text: Tr.tr("Medium"); value: "medium" },
                MenuItem { text: Tr.tr("High"); value: "high" }
            ]
            active: menuItems.find(item => item.value === LiveWallpaper.setting("browserQuality", "medium")) ?? null
            onSelected: item => LiveWallpaper.setQuiet("browserQuality", item.value)
        }

        NavRow {
            icon: "keyboard"
            text: Tr.tr("Keyboard shortcuts")
            subtext: Tr.tr("Set keys to pause, stop or pick a random live wallpaper")
            onClicked: root.nState.goTo(Object.assign(PageRegistry.target("shortcuts"), {
                path: [],
                text: Tr.tr("Your own shortcuts")
            }))
        }

        SectionHeader {
            text: Tr.tr("Startup and recovery")
        }

        ToggleRow {
            text: Tr.tr("Start at login")
            subtext: Tr.tr("Start the last selected wallpapers when you log in")
            checked: LiveWallpaper.setting("startAtLogin", true)
            onToggled: LiveWallpaper.setQuiet("startAtLogin", checked)
        }

        ToggleRow {
            text: Tr.tr("Restart after a crash")
            subtext: Tr.tr("Restart playback if the renderer exits unexpectedly")
            checked: LiveWallpaper.setting("restartAfterCrash", true)
            onToggled: LiveWallpaper.setQuiet("restartAfterCrash", checked)
        }

        ToggleRow {
            text: Tr.tr("Protect against crashes")
            subtext: Tr.tr("Hold a failed wallpaper selection until you apply a wallpaper again")
            checked: LiveWallpaper.setting("protectAfterCrash", false)
            onToggled: LiveWallpaper.setQuiet("protectAfterCrash", checked)
        }

        ToggleRow {
            text: Tr.tr("Restart after system sleep")
            subtext: Tr.tr("Reload the running wallpaper when the system wakes up")
            checked: LiveWallpaper.setting("restartAfterSleep", false)
            onToggled: LiveWallpaper.setQuiet("restartAfterSleep", checked)
        }

        // The renderer: local Nyks45 fork build (linux-wallpaperengine-nyks-git)
        SectionHeader {
            text: Tr.tr("Renderer")
        }

        InfoRow {
            icon: "memory"
            label: Tr.tr("Live wallpaper engine")
            subtext: Tr.tr("Installed renderer build (linux-wallpaperengine)")
            value: LiveWallpaper.engineVersion || Tr.tr("Not installed")
        }

        SelectRow {
            label: Tr.tr("Log level")
            menuItems: [
                MenuItem { text: Tr.tr("Default"); value: "default" },
                MenuItem { text: Tr.tr("None"); value: "none" },
                MenuItem { text: Tr.tr("Errors only"); value: "error" },
                MenuItem { text: Tr.tr("Verbose"); value: "verbose" }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("logLevel", "default")) ?? null
            onSelected: item => LiveWallpaper.set("logLevel", item.value)
        }

        TextFieldRow {
            label: Tr.tr("CEF command-line options")
            placeholderText: "--enable-features=Example"
            value: LiveWallpaper.setting("cefSwitches", "")
            onEditingFinished: value => LiveWallpaper.set("cefSwitches", value)
        }

        ToggleRow {
            text: Tr.tr("High precision frame timer")
            subtext: Tr.tr("Use submillisecond deadlines for Wayland frame pacing")
            checked: LiveWallpaper.setting("highPrecisionTimer", false)
            onToggled: LiveWallpaper.set("highPrecisionTimer", checked)
        }

        ToggleRow {
            text: Tr.tr("Web developer tools")
            checked: LiveWallpaper.setting("cefDevTools", false)
            onToggled: LiveWallpaper.set("cefDevTools", checked)
        }

        StepperRow {
            visible: LiveWallpaper.setting("cefDevTools", false)
            label: Tr.tr("Developer tools port")
            from: 1024
            to: 65535
            value: LiveWallpaper.setting("cefDevToolsPort", 9222)
            onMoved: v => LiveWallpaper.set("cefDevToolsPort", v)
        }

        NavRow {
            icon: "code"
            text: Tr.tr("Open web developer tools")
            visible: LiveWallpaper.setting("cefDevTools", false)
            enabled: LiveWallpaper.running && LiveWallpaper.hasWebOutput
            onClicked: Quickshell.execDetached(["xdg-open", `http://127.0.0.1:${LiveWallpaper.setting("cefDevToolsPort", 9222)}`])
        }

        NavRow {
            icon: "restart_alt"
            text: Tr.tr("Reset wallpaper settings")
            subtext: Tr.tr("Restore defaults for playback, rendering, and integration")
            onClicked: confirmDialog.ask({
                header: Tr.tr("Reset wallpaper settings?"),
                body: Tr.tr("Saved wallpapers, display assignments, profiles, and playlists are kept."),
                confirmLabel: Tr.tr("Reset"),
                onConfirm: () => LiveWallpaper.resetSettings()
            })
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }

        AppPickerDialog {
            id: appPicker

            hostFlickable: root.flickable
        }
    }

    component RuleChoiceButton: SplitButton {
        id: choiceBtn

        property var options: []
        property int current: 0
        readonly property string value: options[current]?.[0] ?? ""

        type: SplitButton.Tonal
        menuItems: choiceItems.instances
        active: choiceItems.instances[current] ?? null
        fallbackText: options[current]?.[1] ?? ""
        stateLayer.onClicked: choiceBtn.expanded = !choiceBtn.expanded
        menu.onItemSelected: item => {
            const idx = choiceItems.instances.indexOf(item);
            if (idx >= 0)
                choiceBtn.current = idx;
        }

        Variants {
            id: choiceItems

            model: choiceBtn.options

            MenuItem {
                required property var modelData

                text: modelData[1]
                value: modelData[0]
            }
        }
    }
}
