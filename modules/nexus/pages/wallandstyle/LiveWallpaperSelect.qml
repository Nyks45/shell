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
// wallpaperengine draws them). What's on now and the library (search, type,
// filters, sort); the settings are on their own page (LiveSettings).
PageBase {
    id: root

    property string query
    property string typeFilter
    property string tagFilter
    // Wallpaper Engine's filters: source (workshop / built-in / mine / preset),
    // age rating (g / pg13 / r), favourites only
    property string sourceFilter
    property string ageFilter
    property bool favouritesOnly
    property bool showFilters
    readonly property bool filtering: !!(query || typeFilter || tagFilter || sourceFilter || ageFilter || favouritesOnly || compatFilter)
    readonly property bool hasApps: LiveWallpaper.wallpapers.some(w => w.type === "application")
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
        const fav = new Set(favouritesOnly || sortBy === "favourite" ? (LiveWallpaper.config.favourites ?? []) : []);
        const list = LiveWallpaper.wallpapers.filter(w => {
            const grade = compatFilter ? (LiveWallpaper.compat(w.path)?.grade ?? "") : "";
            const src = w.source === "folder" ? "mine" : w.source;
            return (!typeFilter || w.type === typeFilter) && (!tagFilter || w.tags.includes(tagFilter)) && (!sourceFilter || src === sourceFilter) && (!ageFilter || (w.rating || "g") === ageFilter) && (!favouritesOnly || fav.has(w.path)) && (showMature || w.rating === "g" || w.rating === "") && (!q || `${w.title} ${w.tags.join(" ")}`.toLowerCase().includes(q)) && (!compatFilter || (compatFilter === "working" ? grade === "perfect" || grade === "minor" : compatFilter === "untested" ? !grade : compatFilter === "hidebroken" ? grade !== "broken" : true));
        });
        const by = {
            name: (a, b) => a.title.localeCompare(b.title),
            favourite: (a, b) => fav.has(b.path) - fav.has(a.path) || a.title.localeCompare(b.title),
            newest: (a, b) => b.added - a.added,
            updated: (a, b) => (b.updated ?? 0) - (a.updated ?? 0),
            size: (a, b) => b.size - a.size,
            recent: (a, b) => (hist[b.path] ?? 0) - (hist[a.path] ?? 0) || b.added - a.added
        }[sortBy] ?? ((a, b) => 0);
        return list.sort(by);
    }

    function resetFilters(): void {
        query = "";
        searchField.text = "";
        typeFilter = "";
        tagFilter = "";
        sourceFilter = "";
        ageFilter = "";
        favouritesOnly = false;
        LiveWallpaper.setQuiet("compatFilter", "");
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
            readonly property string what: Tr.tr("Install the live wallpaper renderer")
            readonly property bool busy: Admin.jobs.some(j => j.what === what)
            // paru's last output line (download, build...)
            readonly property string progress: (Admin.outputOf(what).trim().split("\n").pop() ?? "").slice(0, 120)

            visible: !LiveWallpaper.hasEngine
            icon: "wallpaper"
            text: Tr.tr("Needs linux-wallpaperengine")
            subtext: busy ? (progress || Tr.tr("Building…")) : Tr.tr("The renderer for Wallpaper Engine wallpapers. Installing it builds the newest version (asks for your password).")
            actionText: busy ? "" : Tr.tr("Install")
            // Built as this user from the AUR; paru's install step goes
            // through pkexec (the shell's password prompt)
            onAction: Admin.exec(["paru", "-S", "--needed", "--noconfirm", "--skipreview", "--sudo", "pkexec", "linux-wallpaperengine-git"], what, () => LiveWallpaper.refresh())
        }

        RequirementRow {
            visible: LiveWallpaper.hasEngine && !LiveWallpaper.hasScript
            text: Tr.tr("The live-wallpaper command is missing")
            subtext: Tr.tr("It starts the renderer, here and at login.")
            actionText: Tr.tr("Set up")
            onAction: Quickshell.execDetached(["sh", "-c", `mkdir -p ~/.local/bin && ln -sf '${Quickshell.shellDir}/assets/live-wallpaper' ~/.local/bin/live-wallpaper`])
        }

        // What's on now
        ConnectedRect {
            Layout.fillWidth: true
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
                    still: LiveWallpaper.currentInfo?.still ?? ""
                    frame: LiveWallpaper.currentFrame
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

                        // A playlist: its next wallpaper
                        TextButton {
                            visible: LiveWallpaper.current.startsWith("playlist:")
                            text: Tr.tr("Next")
                            type: TextButton.Tonal
                            onClicked: LiveWallpaper.nextInPlaylist(LiveWallpaper.current.slice(9))
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

        // Playlists, the Workshop and the settings: compact buttons, not full rows
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "storefront"
                text: Tr.tr("Workshop")
                type: TextButton.Tonal
                isRound: true
                onClicked: root.nState.openSubPage(7)
            }

            IconTextButton {
                icon: "playlist_play"
                text: LiveWallpaper.playlists.length ? Tr.tr("Playlists (%1)").arg(LiveWallpaper.playlists.length) : Tr.tr("Playlists")
                type: TextButton.Tonal
                isRound: true
                onClicked: root.nState.openSubPage(6)
            }

            IconTextButton {
                icon: "tune"
                text: Tr.tr("Settings")
                type: TextButton.Tonal
                isRound: true
                onClicked: root.nState.openSubPage(8)
            }
        }

        // The library
        SectionHeader {
            text: LiveWallpaper.scanning ? Tr.tr("Looking for wallpapers…") : root.filtering ? Tr.tr("Your wallpapers (%1 of %2)").arg(root.shown.length).arg(LiveWallpaper.wallpapers.length) : Tr.tr("Your wallpapers (%1)").arg(root.shown.length)
        }

        // The search on its own row (its hint isn't cut off), the chips below
        StyledTextField {
            id: searchField

            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            leadingIcon: "search"
            placeholderText: Tr.tr("Search your wallpapers by name or tag")
            onTextChanged: root.query = text
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

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
                ].concat(root.hasApps ? [
                    {
                        value: "application",
                        text: Tr.tr("Apps")
                    }
                ] : [])

                TextButton {
                    required property var modelData

                    text: modelData.text
                    isToggle: true
                    followChecked: true
                    checked: root.typeFilter === modelData.value
                    type: TextButton.Tonal
                    // The chosen one again: off, back to all
                    onClicked: {
                        root.typeFilter = root.typeFilter === modelData.value ? "" : modelData.value;
                    }
                }
            }

            TextButton {
                text: Tr.tr("Favourites")
                isToggle: true
                followChecked: true
                checked: root.favouritesOnly
                type: TextButton.Tonal
                onClicked: {
                    root.favouritesOnly = !root.favouritesOnly;
                }
            }

            // Sort and the other filters, folded away by default
            TextButton {
                readonly property int active: [root.tagFilter, root.sourceFilter, root.ageFilter, root.compatFilter].filter(x => x).length

                text: active ? Tr.tr("Filters (%1)").arg(active) : Tr.tr("Filters")
                isToggle: true
                followChecked: true
                checked: root.showFilters
                type: TextButton.Tonal
                onClicked: {
                    root.showFilters = !root.showFilters;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.filtering
            Layout.bottomMargin: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Showing %1 of %2").arg(root.shown.length).arg(LiveWallpaper.wallpapers.length)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            TextButton {
                text: Tr.tr("Reset filters")
                type: TextButton.Text
                onClicked: root.resetFilters()
            }
        }

        SelectRow {
            visible: root.showFilters
            label: Tr.tr("Sort by")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Recently used")
                    value: "recent"
                },
                MenuItem {
                    text: Tr.tr("Name")
                    value: "name"
                },
                MenuItem {
                    text: Tr.tr("Favourite")
                    value: "favourite"
                },
                MenuItem {
                    text: Tr.tr("File size")
                    value: "size"
                },
                MenuItem {
                    text: Tr.tr("Subscription date")
                    value: "newest"
                },
                MenuItem {
                    text: Tr.tr("Last updated")
                    value: "updated"
                }
            ]
            active: menuItems.find(i => i.value === root.sortBy) ?? null
            onSelected: item => LiveWallpaper.setQuiet("sortBy", item.value)
        }

        SelectRow {
            visible: root.showFilters
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
            visible: root.showFilters
            label: Tr.tr("Source")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Any")
                    value: ""
                },
                MenuItem {
                    text: Tr.tr("Workshop")
                    value: "workshop"
                },
                MenuItem {
                    text: Tr.tr("Official")
                    value: "built-in"
                },
                MenuItem {
                    text: Tr.tr("My wallpapers")
                    value: "mine"
                },
                MenuItem {
                    text: Tr.tr("Presets")
                    value: "preset"
                }
            ]
            active: menuItems.find(i => i.value === root.sourceFilter) ?? null
            onSelected: item => root.sourceFilter = item.value
        }

        SelectRow {
            visible: root.showFilters && root.showMature
            label: Tr.tr("Age rating")
            menuItems: [
                MenuItem {
                    text: Tr.tr("Any")
                    value: ""
                },
                MenuItem {
                    text: Tr.tr("Everyone")
                    value: "g"
                },
                MenuItem {
                    text: Tr.tr("Questionable")
                    value: "pg13"
                },
                MenuItem {
                    text: Tr.tr("Mature")
                    value: "r"
                }
            ]
            active: menuItems.find(i => i.value === root.ageFilter) ?? null
            onSelected: item => root.ageFilter = item.value
        }

        SelectRow {
            visible: root.showFilters
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
            visible: root.showFilters
            text: Tr.tr("Show mature wallpapers")
            subtext: Tr.tr("Ones rated Questionable or Mature on the Workshop")
            checked: root.showMature
            onToggled: LiveWallpaper.setQuiet("showMature", checked)
        }

        RowButton {
            visible: root.showFilters
            Layout.topMargin: Tokens.spacing.small
            groupStart: true
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
    }

    // A preview: animated ones play on hover (all of them at once would be heavy)
    component Preview: ClipRect {
        id: prev

        property string source
        // A still that isn't black (for GIFs that fade in), else source's first frame
        property string still
        // A full-size frame (the renderer's), preferred when it exists
        property string frame
        property bool playing

        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainerHigh

        // A still (a GIF's first frame, decoded in the background): an
        // AnimatedImage decodes every frame up front, ~100 of them took seconds
        Image {
            anchors.fill: parent
            visible: frameImg.status !== Image.Ready
            source: prev.still || prev.source ? `file://${prev.still || prev.source}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 360
        }

        Image {
            id: frameImg

            anchors.fill: parent
            source: prev.frame ? `file://${prev.frame}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 640
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
                still: card.modelData.still ?? ""
                playing: cardState.containsMouse

                // Favourite: always shown when set, else on hover
                StyledRect {
                    readonly property bool fav: LiveWallpaper.isFavourite(card.modelData.path)

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 6
                    visible: fav || cardState.containsMouse || heartArea.containsMouse
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: Qt.alpha(Colours.palette.m3scrim, 0.55)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "favorite"
                        fill: parent.fav ? 1 : 0
                        color: parent.fav ? "#ff5370" : "white"
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: heartArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LiveWallpaper.toggleFavourite(card.modelData.path)
                    }
                }
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
