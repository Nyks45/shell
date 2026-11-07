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

    // Wallpaper Engine's show/hide rule for a property, e.g.
    // "background_enable.value && background_type.value == 2". It comes from
    // the wallpaper's files, so it's never run as code: a small parser that
    // only knows property values, numbers, true/false, strings, ! && || and
    // comparisons. Anything else shows the property.
    function condOk(expr: string): bool {
        if (!expr)
            return true;
        // "rule ? <restyle the label> : false": shown when the rule holds; a
        // ternary of two restylings: always shown (only the label changes)
        const q = expr.indexOf("?");
        if (q >= 0)
            return /:\s*false\s*$/.test(expr) ? condOk(expr.slice(0, q)) : true;
        const re = /\s*(\(|\)|!=|==|>=|<=|&&|\|\||!|>|<|-?\d+(?:\.\d+)?|true|false|"[^"]*"|'[^']*'|[A-Za-z_][\w]*\.value)/y;
        const toks = [];
        let pos = 0;
        while (pos < expr.length) {
            if (!expr.slice(pos).trim())
                break;
            re.lastIndex = pos;
            const m = re.exec(expr);
            if (!m)
                return true;
            toks.push(m[1]);
            pos = re.lastIndex;
        }
        let i = 0;
        const peek = () => toks[i];
        const val = v => v === "true" ? true : v === "false" ? false : (v !== "" && v !== null && v !== undefined && !isNaN(Number(v)) && typeof v !== "boolean") ? Number(v) : v;
        const primary = () => {
            const t = toks[i++];
            if (t === undefined)
                throw "end";
            if (t === "(") {
                const v = or();
                if (toks[i++] !== ")")
                    throw "paren";
                return v;
            }
            if (t === "!")
                return !truthy(primary());
            if (t === "true" || t === "false")
                return t === "true";
            if (/^-?\d/.test(t))
                return Number(t);
            if (/^["']/.test(t))
                return t.slice(1, -1);
            const name = t.slice(0, -6);
            const p = (w.properties ?? []).find(x => x.name === name);
            return val(p ? propValue(p) : undefined);
        };
        const truthy = v => v === true || (typeof v === "number" && v !== 0) || (typeof v === "string" && v !== "" && v !== "0" && v !== "false");
        const cmp = () => {
            let a = primary();
            while (["==", "!=", ">", "<", ">=", "<="].includes(peek())) {
                const op = toks[i++];
                const b = primary();
                const x = typeof a === "boolean" || typeof b === "boolean" ? truthy(a) : a;
                const y = typeof a === "boolean" || typeof b === "boolean" ? truthy(b) : b;
                a = op === "==" ? x == y : op === "!=" ? x != y : op === ">" ? x > y : op === "<" ? x < y : op === ">=" ? x >= y : x <= y;
            }
            return a;
        };
        const and = () => {
            let a = truthy(cmp());
            while (peek() === "&&") {
                i++;
                const b = truthy(cmp());
                a = a && b;
            }
            return a;
        };
        const or = () => {
            let a = and();
            while (peek() === "||") {
                i++;
                const b = and();
                a = a || b;
            }
            return a;
        };
        try {
            const r = or();
            return i === toks.length ? r : true;
        } catch (e) {
            return true;
        }
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
            id: infoPreview

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(width * 9 / 16, 360)
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            // Shown at once: the still (a GIF's first non-black frame, or the
            // picture); for the wallpaper that's on, the renderer's sharp
            // full-size frame instead of the small preview
            readonly property bool isCurrent: LiveWallpaper.currentInfo?.path === root.path

            Image {
                id: infoStill

                anchors.fill: parent
                source: root.w.still || root.w.preview ? `file://${root.w.still || root.w.preview}` : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 1280
            }

            Image {
                id: infoFrame

                anchors.fill: parent
                visible: infoPreview.isCurrent && status === Image.Ready
                source: infoPreview.isCurrent && LiveWallpaper.currentFrame ? `file://${LiveWallpaper.currentFrame}` : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: 1280
            }

            // The animation: decoded in the background (it decodes every frame
            // first, which took seconds), faded in over the still when ready.
            // Not for the wallpaper that's on (its sharp frame looks better).
            Loader {
                anchors.fill: parent
                active: !infoPreview.isCurrent && (root.w.preview ?? "").toLowerCase().endsWith(".gif")
                asynchronous: true
                opacity: item?.status === AnimatedImage.Ready ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }

                sourceComponent: AnimatedImage {
                    source: `file://${root.w.preview}`
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    playing: true
                }
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

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            TextButton {
                text: Tr.tr("Use this wallpaper")
                type: TextButton.Filled
                onClicked: LiveWallpaper.apply(root.path, "*")
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
                // Hidden by its show/hide rule (re-checked as values change)
                visible: root.condOk(modelData.condition)
                active: visible
                sourceComponent: ({
                        bool: boolProp,
                        slider: sliderProp,
                        combo: comboProp,
                        color: colorProp,
                        textinput: textProp,
                        group: groupProp,
                        text: noteProp,
                        file: pathProp,
                        directory: pathProp,
                        scenetexture: pathProp,
                        usershortcut: shortcutProp
                    })[modelData.type] ?? null

                // A heading for the ones after it
                Component {
                    id: groupProp

                    StyledText {
                        topPadding: Tokens.spacing.medium
                        bottomPadding: Tokens.spacing.extraSmall
                        leftPadding: Tokens.padding.small
                        text: propLoader.modelData.label
                        font: Tokens.font.label.large
                        color: Colours.palette.m3primary
                        wrapMode: Text.WordWrap
                    }
                }

                // The author's note (its HTML as plain text)
                Component {
                    id: noteProp

                    StyledText {
                        topPadding: Tokens.spacing.extraSmall
                        bottomPadding: Tokens.spacing.extraSmall
                        leftPadding: Tokens.padding.small
                        text: propLoader.modelData.label
                        font: Tokens.font.label.medium
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }
                }

                // A file, folder or texture: its path
                Component {
                    id: pathProp

                    TextFieldRow {
                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        label: propLoader.modelData.label
                        placeholderText: propLoader.modelData.type === "directory" ? Tr.tr("A folder, e.g. ~/Pictures") : Tr.tr("A file, e.g. ~/Pictures/picture.jpg")
                        value: String(root.propValue(propLoader.modelData) ?? "")
                        onEditingFinished: v => root.setProp(propLoader.modelData, v.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
                    }
                }

                // A command the wallpaper offers: not run (it's meant for
                // Windows, and running what wallpapers ship isn't safe)
                Component {
                    id: shortcutProp

                    InfoRow {
                        first: propLoader.index === 0
                        last: propLoader.index === props.count - 1
                        icon: "terminal"
                        label: propLoader.modelData.label
                        subtext: Tr.tr("A shortcut the wallpaper offers; not run on Linux")
                    }
                }

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
