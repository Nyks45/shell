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

// One live wallpaper: preview and details, apply (all monitors or one), its
// compatibility, playlists, and its own settings: scaling, sound, effects
// and the properties its author made adjustable (project.json).
PageBase {
    id: root

    readonly property var w: nState.selectedLiveWallpaper ?? {}
    readonly property string path: w.path ?? ""
    readonly property var o: LiveWallpaper.override(path)
    readonly property var c: LiveWallpaper.compat(path)
    readonly property var monitors: Hypr.monitors.values.map(m => m.name)
    readonly property var onScreens: Object.entries(LiveWallpaper.screens).filter(([, v]) => v === path).map(([k]) => k)

    function human(bytes: real): string {
        const u = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (bytes >= 1000 && i < u.length - 1) {
            bytes /= 1000;
            i++;
        }
        return `${bytes >= 100 || i === 0 ? Math.round(bytes) : bytes.toFixed(1)} ${u[i]}`;
    }

    // Property colours are "r g b" in 0..1
    function toHex(rgb: string): string {
        const p = String(rgb ?? "0 0 0").split(/\s+/).map(Number);
        return "#" + p.slice(0, 3).map(v => Math.round(Math.max(0, Math.min(1, v || 0)) * 255).toString(16).padStart(2, "0")).join("");
    }

    function fromHex(hex: string): string {
        const m = hex.trim().replace(/^#/, "").match(/^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
        return m ? [1, 2, 3].map(i => (parseInt(m[i], 16) / 255).toFixed(5)).join(" ") : "";
    }

    function propValue(p: var): var {
        const v = (o.properties ?? {})[p.name];
        return v === undefined ? p.value : v;
    }

    // Back to the author's value removes the change
    function setProp(p: var, v: var): void {
        LiveWallpaper.setProperty(path, p.name, String(v) === String(p.value) ? null : v);
    }

    title: w.title ?? Tr.tr("Live wallpaper")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ClipRect {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(width * 9 / 16, 360)
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            AnimatedImage {
                anchors.fill: parent
                source: root.w.preview ? `file://${root.w.preview}` : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                playing: true
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            text: [root.w.type ? root.w.type.charAt(0).toUpperCase() + root.w.type.slice(1) : "", {
                    workshop: Tr.tr("Workshop"),
                    "built-in": Tr.tr("Built in"),
                    mine: Tr.tr("Made by you"),
                    preset: Tr.tr("Preset"),
                    folder: Tr.tr("Your folder")
                }[root.w.source] ?? "", root.w.size ? root.human(root.w.size) : "", root.onScreens.length ? Tr.tr("On %1").arg(root.onScreens.join(", ").replace("*", Tr.tr("all monitors"))) : ""].filter(s => s).join(" · ")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: (root.w.tags ?? []).length > 0
            text: (root.w.tags ?? []).join(", ")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            TextButton {
                text: root.monitors.length > 1 ? Tr.tr("Use on all monitors") : Tr.tr("Use this wallpaper")
                type: TextButton.Filled
                onClicked: LiveWallpaper.apply(root.path, "*")
            }

            Repeater {
                model: root.monitors.length > 1 ? root.monitors : []

                TextButton {
                    required property string modelData

                    text: Tr.tr("Only %1").arg(modelData)
                    type: TextButton.Tonal
                    onClicked: LiveWallpaper.apply(root.path, modelData)
                }
            }

            TextButton {
                visible: root.onScreens.length > 0
                text: Tr.tr("Turn off")
                type: TextButton.Text
                onClicked: {
                    for (const s of root.onScreens)
                        LiveWallpaper.stopScreen(s);
                }
            }

            TextButton {
                readonly property bool fav: LiveWallpaper.isFavourite(root.path)

                text: fav ? Tr.tr("♥ Favourite") : Tr.tr("♡ Add to favourites")
                type: TextButton.Tonal
                onClicked: LiveWallpaper.toggleFavourite(root.path)
            }

            TextButton {
                text: Tr.tr("Open folder")
                type: TextButton.Text
                onClicked: Quickshell.execDetached(["xdg-open", root.path])
            }

            // Downloaded into the library: unsubscribe (Steam too when signed in) and remove
            TextButton {
                property bool confirm

                visible: root.w.source === "workshop" && root.path.includes("/caelestia/wallpaper-engine/workshop/")
                text: confirm ? Tr.tr("Remove it? Click again") : Tr.tr("Unsubscribe")
                type: TextButton.Text
                onClicked: {
                    if (!confirm) {
                        confirm = true;
                        return;
                    }
                    // Not on a screen any more before its folder goes
                    for (const s of root.onScreens)
                        LiveWallpaper.stopScreen(s);
                    LiveWallpaper.removeWallpaper(root.w.id);
                    root.nState.back();
                }
            }

            TextButton {
                visible: root.w.source === "workshop"
                text: Tr.tr("Workshop page")
                type: TextButton.Text
                onClicked: LiveWallpaper.openInSteam(root.w.id)
            }
        }

        // Compatibility with linux-wallpaperengine
        SectionHeader {
            first: true
            text: Tr.tr("Works with Linux")
        }

        SelectRow {
            first: true
            last: !(root.c?.errors ?? []).length
            label: {
                const g = root.c?.grade ?? "";
                return {
                    perfect: Tr.tr("Works"),
                    minor: Tr.tr("Works, with small glitches"),
                    major: Tr.tr("Parts don't work"),
                    broken: Tr.tr("Doesn't work")
                }[g] ?? Tr.tr("Not tested yet");
            }
            subtext: root.c?.manual ? Tr.tr("Set by you") : root.c?.grade ? Tr.tr("From a test run") : Tr.tr("Test all on the Live wallpapers page, or set it here")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Automatic (test result)")
                    value: ""
                },
                MenuItem {
                    text: Tr.tr("Works")
                    icon: "check_circle"
                    value: "perfect"
                },
                MenuItem {
                    text: Tr.tr("Small glitches")
                    icon: "info"
                    value: "minor"
                },
                MenuItem {
                    text: Tr.tr("Parts don't work")
                    icon: "warning"
                    value: "major"
                },
                MenuItem {
                    text: Tr.tr("Doesn't work")
                    icon: "cancel"
                    value: "broken"
                }
            ]
            active: menuItems.find(i => i.value === (root.c?.manual ?? "")) ?? null
            onSelected: item => LiveWallpaper.setCompat(root.path, item.value)
        }

        InfoRow {
            visible: (root.c?.errors ?? []).length > 0
            last: true
            icon: "bug_report"
            label: Tr.tr("What the renderer said")
            subtext: (root.c?.errors ?? []).join("\n")
        }

        // Playlists
        SectionHeader {
            visible: LiveWallpaper.playlists.length > 0
            text: Tr.tr("Playlists")
        }

        Repeater {
            id: plList

            model: LiveWallpaper.playlists

            ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === plList.count - 1
                text: modelData.name
                subtext: Tr.trN("%n wallpaper", "%n wallpapers", modelData.items.length)
                checked: modelData.items.includes(root.path)
                onToggled: {
                    const items = checked ? [...modelData.items, root.path] : modelData.items.filter(i => i !== root.path);
                    LiveWallpaper.savePlaylist(Object.assign({}, modelData, {
                        items
                    }), modelData.name);
                }
            }
        }

        // Its own settings (over the general ones on the Live wallpapers page)
        SectionHeader {
            text: Tr.tr("For this wallpaper")
        }

        SelectRow {
            first: true
            label: Tr.tr("Fit")
            menuItems: [
                MenuItem {
                    text: Tr.tr("As set for all")
                    value: ""
                },
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
            active: menuItems.find(i => i.value === (root.o.scaling ?? "")) ?? null
            onSelected: item => LiveWallpaper.setOverride(root.path, "scaling", item.value || null)
        }

        SliderRow {
            visible: !LiveWallpaper.setting("silent", true)
            icon: "volume_up"
            label: root.o.volume === undefined ? Tr.tr("Volume (as set for all)") : Tr.tr("Volume")
            valueLabel: `${root.o.volume ?? LiveWallpaper.setting("volume", 50)}%`
            value: (root.o.volume ?? LiveWallpaper.setting("volume", 50)) / 100
            onMoved: v => LiveWallpaper.setOverride(root.path, "volume", Math.round(v * 100))
        }

        OverrideToggle {
            text: Tr.tr("React to music")
            key: "audioProcessing"
            inverted: false
        }

        OverrideToggle {
            text: Tr.tr("React to the mouse")
            key: "disableMouse"
            inverted: true
        }

        OverrideToggle {
            text: Tr.tr("Parallax")
            key: "disableParallax"
            inverted: true
        }

        OverrideToggle {
            last: !(root.w.properties ?? []).length && !Object.keys(root.o).length
            text: Tr.tr("Particles")
            key: "disableParticles"
            inverted: true
        }

        RowButton {
            visible: Object.keys(root.o).length > 0
            last: !(root.w.properties ?? []).length
            icon: "restart_alt"
            text: Tr.tr("Back to the general settings and the author's values")
            onClicked: LiveWallpaper.resetOverrides(root.path)
        }

        // The author's adjustable properties
        SectionHeader {
            visible: (root.w.properties ?? []).length > 0
            text: Tr.tr("Customise")
        }

        Repeater {
            id: props

            model: root.w.properties ?? []

            Loader {
                id: propLoader

                required property var modelData
                required property int index

                Layout.fillWidth: true
                sourceComponent: ({
                        bool: boolProp,
                        slider: sliderProp,
                        combo: comboProp,
                        color: colorProp,
                        textinput: textProp
                    })[modelData.type] ?? null

                Component {
                    id: boolProp

                    ToggleRow {
                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        text: propLoader.modelData.label
                        checked: {
                            const v = root.propValue(propLoader.modelData);
                            return v === true || v === 1 || v === "1" || v === "true";
                        }
                        onToggled: root.setProp(propLoader.modelData, checked)
                    }
                }

                Component {
                    id: sliderProp

                    SliderRow {
                        readonly property real minV: Number(propLoader.modelData.min ?? 0)
                        readonly property real maxV: Number(propLoader.modelData.max ?? 1)
                        readonly property real stepV: Number(propLoader.modelData.step ?? ((maxV - minV) / 100))
                        readonly property real cur: Number(root.propValue(propLoader.modelData) ?? minV)

                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        icon: "tune"
                        label: propLoader.modelData.label
                        valueLabel: stepV >= 1 ? String(Math.round(cur)) : cur.toFixed(2)
                        value: maxV > minV ? (cur - minV) / (maxV - minV) : 0
                        onMoved: v => {
                            const raw = minV + v * (maxV - minV);
                            const snapped = stepV > 0 ? Math.round(raw / stepV) * stepV : raw;
                            root.setProp(propLoader.modelData, Math.round(snapped * 1e5) / 1e5);
                        }
                    }
                }

                Component {
                    id: comboProp

                    SelectRow {
                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        label: propLoader.modelData.label
                        menuItems: comboItems.instances
                        active: comboItems.instances.find(i => String(i.value) === String(root.propValue(propLoader.modelData))) ?? null
                        fallbackText: String(root.propValue(propLoader.modelData))
                        onSelected: item => root.setProp(propLoader.modelData, item.value)

                        Variants {
                            id: comboItems

                            model: propLoader.modelData.options ?? []

                            MenuItem {
                                required property var modelData

                                text: modelData.label
                                value: modelData.value
                            }
                        }
                    }
                }

                Component {
                    id: colorProp

                    ConnectedRect {
                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        implicitHeight: colorRow.implicitHeight + Tokens.padding.small * 2

                        RowLayout {
                            id: colorRow

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            StyledText {
                                Layout.fillWidth: true
                                text: propLoader.modelData.label
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            // A few colours to pick from, then any as hex
                            Repeater {
                                model: [root.toHex(propLoader.modelData.value), "#ffffff", "#000000", Colours.palette.m3primary.toString(), "#e53935", "#43a047", "#1e88e5"]

                                StyledRect {
                                    required property string modelData

                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 11
                                    color: modelData
                                    border.width: root.toHex(root.propValue(propLoader.modelData)).toLowerCase() === String(modelData).toLowerCase().slice(0, 7) ? 2 : 1
                                    border.color: Colours.palette.m3outline

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        onClicked: root.setProp(propLoader.modelData, root.fromHex(String(parent.modelData).slice(0, 7)))
                                    }
                                }
                            }

                            StyledTextField {
                                Layout.preferredWidth: 90
                                text: root.toHex(root.propValue(propLoader.modelData))
                                font: Tokens.font.mono.small
                                onAccepted: {
                                    const v = root.fromHex(text);
                                    if (v)
                                        root.setProp(propLoader.modelData, v);
                                }
                            }
                        }
                    }
                }

                Component {
                    id: textProp

                    TextFieldRow {
                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        label: propLoader.modelData.label
                        value: String(root.propValue(propLoader.modelData) ?? "")
                        onEditingFinished: v => root.setProp(propLoader.modelData, v)
                    }
                }
            }
        }
    }

    // One of the general on/off settings, for this wallpaper only
    component OverrideToggle: ToggleRow {
        required property string key
        required property bool inverted
        readonly property var own: root.o[key]
        readonly property var general: LiveWallpaper.setting(key, inverted ? false : true)

        subtext: own === undefined ? Tr.tr("As set for all") : Tr.tr("Just for this one")
        checked: inverted ? !(own ?? general) : (own ?? general)
        onToggled: {
            const v = inverted ? !checked : checked;
            LiveWallpaper.setOverride(root.path, key, v === general ? null : v);
        }
    }
}
