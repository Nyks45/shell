pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

// Live wallpaper settings (all live wallpapers): playback, folders and the
// renderer's version. Moved out of the wallpapers page so the list comes first.
PageBase {
    id: root

    readonly property var monitors: Hypr.monitors.values.map(m => m.name)

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
                mute: Tr.tr("mute"),
                stop: Tr.tr("stop (free memory)")
            })[a] ?? a;
    }

    title: Tr.tr("Live wallpaper settings")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Playback (all live wallpapers)
        SectionHeader {
            text: Tr.tr("Playback")
        }

        SelectRow {
            first: true
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
                    return [15, 24, 30, 60, 90, 120, 144, 165, 240, 360].filter(f => f <= maxRate);
                }

                MenuItem {
                    required property int modelData

                    text: `${modelData} fps`
                    value: modelData
                }
            }
        }

        SelectRow {
            label: Tr.tr("Post-processing")
            subtext: Tr.tr("Ultra enables HDR bloom in wallpapers that support it")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Off")
                    value: "off"
                },
                MenuItem {
                    text: Tr.tr("Normal")
                    value: "normal"
                },
                MenuItem {
                    text: Tr.tr("Ultra / HDR bloom")
                    value: "ultra"
                }
            ]
            active: menuItems.find(i => i.value === LiveWallpaper.setting("postProcessing", "ultra")) ?? null
            onSelected: item => LiveWallpaper.set("postProcessing", item.value)
        }

        ToggleRow {
            text: Tr.tr("Pause behind fullscreen apps")
            subtext: Tr.tr("Games and videos get the GPU to themselves")
            checked: LiveWallpaper.setting("pauseOnFullscreen", true)
            onToggled: LiveWallpaper.set("pauseOnFullscreen", checked)
        }

        // Fullscreen apps that don't pause it (their app id, or a part of it)
        StringListEditor {
            visible: LiveWallpaper.setting("pauseOnFullscreen", true)
            values: LiveWallpaper.setting("pauseIgnore", [])
            placeholderText: Tr.tr("Don't pause for this app (its app id, e.g. mpv)")
            emptyText: Tr.tr("Every fullscreen app pauses it")
            onEdited: v => LiveWallpaper.set("pauseIgnore", v)
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

        ToggleRow {
            visible: !LiveWallpaper.setting("silent", true)
            text: Tr.tr("Quiet while other apps play sound")
            checked: !LiveWallpaper.setting("noAutomute", false)
            onToggled: LiveWallpaper.set("noAutomute", !checked)
        }

        ToggleRow {
            text: Tr.tr("React to music")
            subtext: Tr.tr("Audio visualisers in wallpapers follow what's playing")
            checked: LiveWallpaper.setting("audioProcessing", true)
            onToggled: LiveWallpaper.set("audioProcessing", checked)
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
                    text: Tr.tr("Fit (bars at the sides)")
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

        ToggleRow {
            last: true
            text: Tr.tr("Particles")
            subtext: Tr.tr("Off saves GPU on busy wallpapers")
            checked: !LiveWallpaper.setting("disableParticles", false)
            onToggled: LiveWallpaper.set("disableParticles", !checked)
        }

        // Where wallpapers are found
        // Wallpaper Engine's "Other application ..." rules and its app rules
        SectionHeader {
            text: Tr.tr("When other apps are in use")
        }

        Repeater {
            model: [
                {
                    key: "focused",
                    text: Tr.tr("Another app is focused")
                },
                {
                    key: "maximized",
                    text: Tr.tr("An app is maximized")
                },
                {
                    key: "audio",
                    text: Tr.tr("Media is playing"),
                    sub: Tr.tr("Music, videos, browsers (anything that shows in the media controls)")
                }
            ]

            SelectRow {
                required property var modelData
                required property int index

                first: index === 0
                label: modelData.text
                subtext: modelData.sub ?? ""
                menuItems: [
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
                    }
                ]
                active: menuItems.find(i => i.value === LiveWallpaper.playbackRules[modelData.key]) ?? null
                onSelected: item => LiveWallpaper.setPlaybackRule(modelData.key, item.value)
            }
        }

        InfoRow {
            last: true
            icon: LiveWallpaper.ruleAction === "run" ? "play_circle" : LiveWallpaper.ruleAction === "mute" ? "volume_off" : LiveWallpaper.ruleAction === "pause" ? "pause_circle" : "stop_circle"
            label: Tr.tr("Now")
            subtext: LiveWallpaper.ruleAction === "run" ? Tr.tr("No rule applies") : LiveWallpaper.ruleReason
            value: ({
                    run: Tr.tr("Playing"),
                    mute: Tr.tr("Muted"),
                    pause: Tr.tr("Paused"),
                    stop: Tr.tr("Stopped")
                })[LiveWallpaper.ruleAction] ?? ""
        }

        // App rules: this app running / focused / maximized / fullscreen / playing -> action
        SectionHeader {
            text: Tr.tr("App rules")
        }

        Repeater {
            id: ruleList

            model: LiveWallpaper.appRules

            RowButton {
                required property var modelData
                required property int index
                property bool confirm

                first: index === 0
                icon: "rule"
                text: modelData.app
                subtext: confirm ? Tr.tr("Click again to delete this rule") : `${root.whenText(modelData.when)} → ${root.actionText(modelData.action)}`
                trailingIcon: "delete"
                onClicked: {
                    if (!confirm) {
                        confirm = true;
                        return;
                    }
                    LiveWallpaper.setAppRules(LiveWallpaper.appRules.filter((r, i) => i !== index));
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: LiveWallpaper.appRules.length === 0
            last: true
            implicitHeight: ruleCol.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: ruleCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                StyledText {
                    text: Tr.tr("New rule")
                    font: Tokens.font.body.small
                }

                StyledTextField {
                    id: ruleApp

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("App (its window class, e.g. steam_app or firefox)")
                }

                // Running apps, to pick from
                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: [...new Set(Hypr.toplevels.values.map(t => t.lastIpcObject?.class ?? "").filter(c => c))].sort()

                        TextButton {
                            required property string modelData

                            text: modelData
                            type: TextButton.Text
                            onClicked: ruleApp.text = modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    SelectButtonLike {
                        id: ruleWhen

                        options: [["running", root.whenText("running")], ["focused", root.whenText("focused")], ["maximized", root.whenText("maximized")], ["fullscreen", root.whenText("fullscreen")], ["audio", root.whenText("audio")]]
                    }

                    StyledText {
                        text: "→"
                    }

                    SelectButtonLike {
                        id: ruleAction

                        options: [["pause", root.actionText("pause")], ["mute", root.actionText("mute")], ["stop", root.actionText("stop")]]
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: Tr.tr("Add")
                        type: TextButton.Filled
                        disabled: !ruleApp.text.trim()
                        onClicked: {
                            LiveWallpaper.setAppRules(LiveWallpaper.appRules.concat([{
                                    app: ruleApp.text.trim(),
                                    when: ruleWhen.value,
                                    action: ruleAction.value
                                }]));
                            ruleApp.text = "";
                        }
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Folders")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Wallpaper Engine folder")
            subtext: LiveWallpaper.setting("assetsDir", "") ? Tr.tr("Set by you; empty to find it by itself") : Tr.tr("Found by itself: %1").arg(Paths.shortenHome(LiveWallpaper.assetsDetected.replace(/\/assets$/, "")) || Tr.tr("not found"))
            value: LiveWallpaper.setting("assetsDir", "")
            placeholderText: Tr.tr("Its assets folder, if it's somewhere unusual")
            onEditingFinished: v => {
                LiveWallpaper.set("assetsDir", v.trim());
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

        StringListEditor {
            values: LiveWallpaper.setting("extraFolders", [])
            placeholderText: Tr.tr("A folder of wallpapers, e.g. ~/Wallpapers/Live")
            onEdited: v => {
                LiveWallpaper.setQuiet("extraFolders", v);
                Qt.callLater(() => LiveWallpaper.refresh());
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.medium
            text: Tr.tr("For shortcuts (Keyboard shortcuts > Your own): caelestia shell liveWallpaper random | pause | stop")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // The renderer: always the newest upstream build (the -git package)
        SectionHeader {
            text: Tr.tr("Renderer")
        }

        InfoRow {
            first: true
            last: true
            icon: "memory"
            label: "linux-wallpaperengine"
            subtext: Tr.tr("The renderer build installed (updated with its package, not from here)")
            value: LiveWallpaper.engineVersion || Tr.tr("Not installed")
        }
    }

    // A compact choice: click to go to the next option
    component SelectButtonLike: TextButton {
        property var options: []
        property int current
        readonly property string value: options[current]?.[0] ?? ""

        text: `${options[current]?.[1] ?? ""} ▾`
        type: TextButton.Tonal
        onClicked: current = (current + 1) % options.length
    }
}
