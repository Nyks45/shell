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

// Live wallpapers: the Wallpaper Engine wallpapers on this PC (linux-
// wallpaperengine draws them). What's on now, the library (search, type,
// sort), playback options and the renderer's version.
PageBase {
    id: root

    property string query
    property string typeFilter
    property string tagFilter
    readonly property string compatFilter: LiveWallpaper.setting("compatFilter", "")
    readonly property var allTags: {
        const count = {};
        for (const w of LiveWallpaper.wallpapers)
            for (const t of w.tags)
                count[t] = (count[t] ?? 0) + 1;
        return Object.keys(count).sort((a, b) => count[b] - count[a]);
    }
    readonly property string sortBy: LiveWallpaper.setting("sortBy", "recent")
    readonly property bool showMature: LiveWallpaper.setting("showMature", false)
    readonly property var monitors: Hypr.monitors.values.map(m => m.name)

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        // Only what the filter and sort in use read (a binding depends on what it
        // touched): changing a playback setting mustn't rebuild every card
        const hist = sortBy === "recent" ? (LiveWallpaper.config.history ?? {}) : {};
        const list = LiveWallpaper.wallpapers.filter(w => {
            const grade = compatFilter ? (LiveWallpaper.compat(w.path)?.grade ?? "") : "";
            return (!typeFilter || w.type === typeFilter) && (!tagFilter || w.tags.includes(tagFilter)) && (showMature || w.rating === "g" || w.rating === "") && (!q || `${w.title} ${w.tags.join(" ")}`.toLowerCase().includes(q)) && (!compatFilter || (compatFilter === "working" ? grade === "perfect" || grade === "minor" : compatFilter === "untested" ? !grade : compatFilter === "hidebroken" ? grade !== "broken" : true));
        });
        const by = {
            name: (a, b) => a.title.localeCompare(b.title),
            newest: (a, b) => b.added - a.added,
            size: (a, b) => b.size - a.size,
            recent: (a, b) => (hist[b.path] ?? 0) - (hist[a.path] ?? 0) || b.added - a.added
        }[sortBy] ?? ((a, b) => 0);
        return list.sort(by);
    }

    function openInfo(w: var): void {
        nState.selectedLiveWallpaper = w;
        nState.openSubPage(5);
    }

    Component.onCompleted: LiveWallpaper.refresh()

    title: Tr.tr("Live wallpapers")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RequirementRow {
            visible: !LiveWallpaper.hasEngine
            first: true
            last: true
            icon: "wallpaper"
            text: Tr.tr("Needs linux-wallpaperengine")
            subtext: Tr.tr("The renderer for Wallpaper Engine wallpapers. Installing it builds the newest version (asks for your password).")
            actionText: Tr.tr("Install")
            onAction: Term.run("paru -S --needed linux-wallpaperengine-git")
        }

        RequirementRow {
            visible: LiveWallpaper.hasEngine && !LiveWallpaper.hasScript
            first: true
            last: true
            text: Tr.tr("The live-wallpaper command is missing")
            subtext: Tr.tr("It starts the renderer, here and at login.")
            actionText: Tr.tr("Set up")
            onAction: Quickshell.execDetached(["sh", "-c", `mkdir -p ~/.local/bin && ln -sf '${Quickshell.shellDir}/assets/live-wallpaper' ~/.local/bin/live-wallpaper`])
        }

        // What's on now
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: nowRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: nowRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.large

                Preview {
                    Layout.preferredWidth: 168
                    Layout.preferredHeight: 96
                    source: LiveWallpaper.currentInfo?.preview ?? ""
                    playing: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: LiveWallpaper.currentInfo?.title ?? (LiveWallpaper.current ? LiveWallpaper.current.split("/").pop() : Tr.tr("No live wallpaper"))
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: !LiveWallpaper.current ? Tr.tr("Pick one below, or a normal wallpaper on the Wallpapers page") : LiveWallpaper.paused ? Tr.tr("Paused") : LiveWallpaper.running ? Tr.tr("Playing") : Tr.tr("Not running")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    RowLayout {
                        spacing: Tokens.spacing.small

                        TextButton {
                            visible: !!LiveWallpaper.currentInfo
                            text: Tr.tr("Customise")
                            type: TextButton.Tonal
                            onClicked: root.openInfo(LiveWallpaper.currentInfo)
                        }

                        TextButton {
                            visible: !!LiveWallpaper.current && LiveWallpaper.running
                            text: LiveWallpaper.paused ? Tr.tr("Resume") : Tr.tr("Pause")
                            type: TextButton.Tonal
                            onClicked: LiveWallpaper.togglePause()
                        }

                        TextButton {
                            text: Tr.tr("Random")
                            type: TextButton.Tonal
                            disabled: LiveWallpaper.wallpapers.length === 0
                            onClicked: LiveWallpaper.random()
                        }

                        TextButton {
                            visible: !!LiveWallpaper.current
                            text: Tr.tr("Turn off")
                            type: TextButton.Text
                            onClicked: LiveWallpaper.useStatic()
                        }
                    }
                }
            }
        }

        // Each monitor: what's on it
        SectionHeader {
            visible: root.monitors.length > 1
            text: Tr.tr("On your monitors")
        }

        Repeater {
            id: monList

            model: root.monitors.length > 1 ? root.monitors : []

            RowButton {
                required property string modelData
                required property int index
                readonly property string target: LiveWallpaper.screens[modelData] ?? LiveWallpaper.screens["*"] ?? ""

                first: index === 0
                last: index === monList.count - 1
                icon: "monitor"
                text: modelData
                subtext: !target ? Tr.tr("Nothing (Caelestia's wallpaper)") : target.startsWith("playlist:") ? Tr.tr("Playlist: %1").arg(target.slice(9)) : (LiveWallpaper.info(target)?.title ?? target.split("/").pop())
                trailingIcon: target ? "close" : ""
                onClicked: {
                    if (target)
                        LiveWallpaper.stopScreen(modelData);
                }
            }
        }

        SectionHeader {
            text: Tr.tr("More")
        }

        NavRow {
            first: true
            icon: "playlist_play"
            text: Tr.tr("Playlists")
            subtext: LiveWallpaper.playlists.length ? Tr.trN("%n playlist", "%n playlists", LiveWallpaper.playlists.length) : Tr.tr("Wallpapers that take turns")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            last: true
            icon: "storefront"
            text: Tr.tr("Steam Workshop")
            subtext: Tr.tr("Find new wallpapers: trending, popular, newest")
            onClicked: root.nState.openSubPage(7)
        }

        // The library
        SectionHeader {
            text: LiveWallpaper.scanning ? Tr.tr("Looking for wallpapers…") : Tr.tr("Your wallpapers (%1)").arg(root.shown.length)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            StyledTextField {
                Layout.fillWidth: true
                placeholderText: Tr.tr("Search by name or tag")
                onTextChanged: root.query = text
            }

            Repeater {
                model: [
                    {
                        value: "",
                        text: Tr.tr("All")
                    },
                    {
                        value: "scene",
                        text: Tr.tr("Scenes")
                    },
                    {
                        value: "video",
                        text: Tr.tr("Videos")
                    },
                    {
                        value: "web",
                        text: Tr.tr("Web")
                    }
                ]

                TextButton {
                    required property var modelData

                    text: modelData.text
                    isToggle: true
                    checked: root.typeFilter === modelData.value
                    type: TextButton.Tonal
                    onClicked: root.typeFilter = modelData.value
                }
            }
        }

        SelectRow {
            first: true
            label: Tr.tr("Sort by")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Recently used")
                    value: "recent"
                },
                MenuItem {
                    text: Tr.tr("Newest")
                    value: "newest"
                },
                MenuItem {
                    text: Tr.tr("Name")
                    value: "name"
                },
                MenuItem {
                    text: Tr.tr("Size")
                    value: "size"
                }
            ]
            active: menuItems.find(i => i.value === root.sortBy) ?? null
            onSelected: item => LiveWallpaper.setQuiet("sortBy", item.value)
        }

        SelectRow {
            label: Tr.tr("Tag")
            menuItems: [anyTag, ...tagItems.instances]
            active: root.tagFilter ? tagItems.instances.find(i => i.value === root.tagFilter) ?? null : anyTag
            onSelected: item => root.tagFilter = item.value

            MenuItem {
                id: anyTag

                text: Tr.tr("Any")
                value: ""
            }

            Variants {
                id: tagItems

                model: root.allTags

                MenuItem {
                    required property string modelData

                    text: modelData
                    value: modelData
                }
            }
        }

        SelectRow {
            label: Tr.tr("Works with Linux")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Show all")
                    value: ""
                },
                MenuItem {
                    text: Tr.tr("Only ones that work")
                    value: "working"
                },
                MenuItem {
                    text: Tr.tr("Hide broken ones")
                    value: "hidebroken"
                },
                MenuItem {
                    text: Tr.tr("Not tested yet")
                    value: "untested"
                }
            ]
            active: menuItems.find(i => i.value === root.compatFilter) ?? null
            onSelected: item => LiveWallpaper.setQuiet("compatFilter", item.value)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show mature wallpapers")
            subtext: Tr.tr("Ones rated Questionable or Mature on the Workshop")
            checked: root.showMature
            onToggled: LiveWallpaper.setQuiet("showMature", checked)
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.small
            first: true
            last: true
            icon: LiveWallpaper.testing ? "hourglass_top" : "fact_check"
            text: LiveWallpaper.testing ? Tr.tr("Testing %1 of %2… (click to stop)").arg(LiveWallpaper.testDone).arg(LiveWallpaper.testTotal) : Tr.tr("Test which wallpapers work")
            subtext: LiveWallpaper.testing ? "" : Tr.tr("Runs each untested one for a few seconds, hidden")
            onClicked: LiveWallpaper.testing ? LiveWallpaper.stopTests() : LiveWallpaper.testAll(false)
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            columns: Math.max(2, Math.floor((width + columnSpacing) / (180 + columnSpacing)))
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
                model: root.shown

                Card {}
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !LiveWallpaper.scanning && LiveWallpaper.wallpapers.length === 0
            text: Tr.tr("No Wallpaper Engine wallpapers found. Get Wallpaper Engine on Steam, then subscribe to some on its Workshop.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

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
            icon: "memory"
            label: "linux-wallpaperengine"
            subtext: LiveWallpaper.engineLatest ? (LiveWallpaper.engineVersion.includes(LiveWallpaper.engineLatest) ? Tr.tr("Up to date") : Tr.tr("A newer version is out (%1)").arg(LiveWallpaper.engineLatest)) : Tr.tr("Built from the newest upstream code")
            value: LiveWallpaper.engineVersion || Tr.tr("Not installed")
            Component.onCompleted: LiveWallpaper.checkEngineUpdate()
        }

        RowButton {
            last: true
            icon: "update"
            text: Tr.tr("Update to the newest version")
            subtext: Tr.tr("Rebuilds it from upstream; opens a terminal")
            onClicked: Term.run("paru -S linux-wallpaperengine-git && live-wallpaper start")
        }
    }

    // A preview: animated ones play on hover (all of them at once would be heavy)
    component Preview: ClipRect {
        id: prev

        property string source
        property bool playing

        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainerHigh

        // A still (a GIF's first frame, decoded in the background): an
        // AnimatedImage decodes every frame up front, ~100 of them took seconds
        Image {
            anchors.fill: parent
            source: prev.source ? `file://${prev.source}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 360
        }

        Loader {
            anchors.fill: parent
            active: prev.playing && prev.source.toLowerCase().endsWith(".gif")
            asynchronous: true

            sourceComponent: AnimatedImage {
                source: `file://${prev.source}`
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                playing: true
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !prev.source
            text: "wallpaper"
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.large
        }
    }

    component Card: StyledRect {
        id: card

        required property var modelData
        readonly property bool current: Object.values(LiveWallpaper.screens).includes(modelData.path)
        readonly property string grade: LiveWallpaper.compat(modelData.path)?.grade ?? ""
        readonly property bool broken: grade === "broken"

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.large
        color: current ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        border.width: current ? 2 : 0
        border.color: Colours.palette.m3primary

        StateLayer {
            id: cardState

            anchors.fill: parent
            radius: parent.radius
            onClicked: root.openInfo(card.modelData)
        }

        ColumnLayout {
            id: cardCol

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall

            Preview {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16
                source: card.modelData.preview
                playing: cardState.containsMouse
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: card.modelData.type === "video" ? "movie" : card.modelData.type === "web" ? "language" : "landscape"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.modelData.title
                    font: Tokens.font.label.medium
                    elide: Text.ElideRight
                }

                // How well it works with the renderer (tested or set by hand)
                StyledRect {
                    visible: !!card.grade
                    implicitWidth: 10
                    implicitHeight: 10
                    radius: 5
                    color: card.grade === "perfect" ? "#43a047" : card.grade === "minor" ? "#fdd835" : card.grade === "major" ? "#fb8c00" : Colours.palette.m3error
                }

                MaterialIcon {
                    visible: card.current
                    text: "check_circle"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                    fill: 1
                }
            }
        }
    }
}
