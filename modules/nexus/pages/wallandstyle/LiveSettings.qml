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

        ToggleRow {
            visible: LiveWallpaper.setting("pauseOnFullscreen", true) && root.monitors.length > 1
            text: Tr.tr("Only on that monitor")
            subtext: Tr.tr("Other monitors keep playing")
            checked: LiveWallpaper.setting("pauseOnlyActive", false)
            onToggled: LiveWallpaper.set("pauseOnlyActive", checked)
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
            visible: root.monitors.length > 1
            text: Tr.tr("Stretch one wallpaper across monitors")
            subtext: Tr.tr("Instead of the same one on each")
            checked: LiveWallpaper.setting("span", false)
            onToggled: LiveWallpaper.set("span", checked)
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
}
