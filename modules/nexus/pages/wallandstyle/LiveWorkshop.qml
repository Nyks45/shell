pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// The Steam Workshop for Wallpaper Engine, like the app's Workshop tab:
// search, Steam's sorts, the Workshop's own filters (type, age rating, genre,
// resolution, ...), ratings, authors and an item's details. Read keyless from
// Steam's public pages (live-wallpaper-scan.py workshop). Subscribing happens
// in Steam, which downloads the wallpaper; it then shows up among yours.
PageBase {
    id: root

    property string sort: "trend"
    property int days: 7
    property string search
    property int page: 1
    // Chosen filters: { group name: [tags] }
    property var chosen: ({})
    property bool showFilters
    // The item whose details are shown (a Workshop entry), or null
    property var selected: null
    readonly property bool showMature: LiveWallpaper.setting("showMature", false)
    readonly property var installed: new Set(LiveWallpaper.wallpapers.map(w => w.id))
    readonly property var chosenTags: Object.values(chosen).reduce((a, b) => a.concat(b), [])
    readonly property int pages: LiveWallpaper.workshopPage.pages ?? 1

    function load(): void {
        LiveWallpaper.loadWorkshop({
            sort,
            days,
            page,
            search,
            tags: chosenTags,
            mature: showMature
        });
    }

    function reload(): void {
        page = 1;
        load();
        flickable.contentY = 0;
    }

    function toggleTag(group: var, tag: string): void {
        const c = Object.assign({}, chosen);
        const cur = c[group.name] ?? [];
        if (cur.includes(tag))
            c[group.name] = cur.filter(t => t !== tag);
        else
            c[group.name] = group.multi ? cur.concat([tag]) : [tag];
        if (c[group.name].length === 0)
            delete c[group.name];
        chosen = c;
        reload();
    }

    function open(item: var): void {
        selected = item;
        LiveWallpaper.loadWorkshopItem(item.id);
        flickable.contentY = 0;
    }

    function count(n: int): string {
        return n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}K` : String(n);
    }

    function size(bytes: real): string {
        return bytes >= 1073741824 ? `${(bytes / 1073741824).toFixed(1)} GB` : `${Math.max(1, Math.round(bytes / 1048576))} MB`;
    }

    // Age ratings beyond "Everyone" only when mature wallpapers are allowed
    function shownTags(group: var): var {
        return group.name === "Age Rating" && !showMature ? group.tags.filter(t => t === "Everyone") : group.tags;
    }

    Component.onCompleted: load()

    title: root.selected ? root.selected.title : Tr.tr("Steam Workshop")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        // Subscribed in Steam meanwhile: check for new ones now and then
        Timer {
            running: root.visible
            repeat: true
            interval: 10000
            onTriggered: LiveWallpaper.refresh()
        }

        // ---- Browsing --------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            visible: !root.selected
            spacing: Tokens.spacing.small

            StyledTextField {
                Layout.fillWidth: true
                leadingIcon: "search"
                placeholderText: Tr.tr("Search the Workshop")
                onAccepted: {
                    root.search = text.trim();
                    root.reload();
                }
            }

            TextButton {
                text: root.chosenTags.length > 0 ? Tr.tr("Filters (%1)").arg(root.chosenTags.length) : Tr.tr("Filters")
                isToggle: true
                checked: root.showFilters
                type: TextButton.Tonal
                onClicked: root.showFilters = !root.showFilters
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: !root.selected && !root.search
            spacing: Tokens.spacing.small

            Repeater {
                model: [
                    {
                        value: "trend",
                        text: Tr.tr("Most popular")
                    },
                    {
                        value: "toprated",
                        text: Tr.tr("Top rated")
                    },
                    {
                        value: "recent",
                        text: Tr.tr("Most recent")
                    },
                    {
                        value: "subscribed",
                        text: Tr.tr("Most subscriptions")
                    },
                    {
                        value: "updated",
                        text: Tr.tr("Last updated")
                    }
                ]

                TextButton {
                    required property var modelData

                    text: modelData.text
                    isToggle: true
                    checked: root.sort === modelData.value
                    type: TextButton.Tonal
                    onClicked: {
                        root.sort = modelData.value;
                        root.reload();
                    }
                }
            }
        }

        // "Most popular" over a period, like the app's Today/Week/Month/Year
        Flow {
            Layout.fillWidth: true
            visible: !root.selected && !root.search && root.sort === "trend"
            spacing: Tokens.spacing.small

            Repeater {
                model: [
                    {
                        value: 1,
                        text: Tr.tr("Today")
                    },
                    {
                        value: 7,
                        text: Tr.tr("This week")
                    },
                    {
                        value: 30,
                        text: Tr.tr("This month")
                    },
                    {
                        value: 365,
                        text: Tr.tr("This year")
                    }
                ]

                TextButton {
                    required property var modelData

                    text: modelData.text
                    isToggle: true
                    checked: root.days === modelData.value
                    type: TextButton.Text
                    onClicked: {
                        root.days = modelData.value;
                        root.reload();
                    }
                }
            }
        }

        // The Workshop's filter groups
        StyledRect {
            Layout.fillWidth: true
            visible: !root.selected && root.showFilters
            implicitHeight: filterCol.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: filterCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                Repeater {
                    model: LiveWallpaper.workshopTagGroups.filter(g => g.name !== "Category")

                    ColumnLayout {
                        id: group

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: group.modelData.name
                            font: Tokens.font.label.large
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            Repeater {
                                model: root.shownTags(group.modelData)

                                TextButton {
                                    required property string modelData

                                    text: modelData
                                    isToggle: true
                                    checked: (root.chosen[group.modelData.name] ?? []).includes(modelData)
                                    type: TextButton.Tonal
                                    onClicked: root.toggleTag(group.modelData, modelData)
                                }
                            }
                        }
                    }
                }

                TextButton {
                    Layout.alignment: Qt.AlignRight
                    visible: root.chosenTags.length > 0
                    text: Tr.tr("Reset filters")
                    type: TextButton.Text
                    onClicked: {
                        root.chosen = {};
                        root.reload();
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.selected

            StyledText {
                Layout.fillWidth: true
                text: LiveWallpaper.workshopLoading ? Tr.tr("Loading…") : root.search ? Tr.tr("%1 results for “%2”").arg(root.count(LiveWallpaper.workshopPage.total ?? 0)).arg(root.search) : Tr.tr("%1 wallpapers").arg(root.count(LiveWallpaper.workshopPage.total ?? 0))
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            TextButton {
                visible: !!root.search
                text: Tr.tr("Clear search")
                type: TextButton.Text
                onClicked: {
                    root.search = "";
                    root.reload();
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !!LiveWallpaper.workshopPage.error
            text: Tr.tr("Couldn't load the Workshop: %1").arg(LiveWallpaper.workshopPage.error ?? "")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            visible: !root.selected
            opacity: LiveWallpaper.workshopLoading ? 0.5 : 1
            columns: Math.max(2, Math.floor((width + columnSpacing) / (190 + columnSpacing)))
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Behavior on opacity {
                Anim {}
            }

            Repeater {
                model: LiveWallpaper.workshopPage.items ?? []

                StyledRect {
                    id: item

                    required property var modelData
                    readonly property bool have: root.installed.has(modelData.id)

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: itemCol.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainer

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: root.open(item.modelData)
                    }

                    ColumnLayout {
                        id: itemCol

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        ClipRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width
                            radius: Tokens.rounding.medium
                            color: Colours.tPalette.m3surfaceContainerHigh

                            Image {
                                anchors.fill: parent
                                source: item.modelData.preview
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 400
                            }

                            Badge {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                visible: item.have
                                text: Tr.tr("Yours")
                            }

                            Stars {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                rating: item.modelData.rating
                                overlay: true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.title
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: [item.modelData.author, Tr.tr("%1 subscribers").arg(root.count(item.modelData.subscriptions))].filter(x => x).join(" · ")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.medium
            visible: !root.selected
            spacing: Tokens.spacing.small

            TextButton {
                text: Tr.tr("Previous")
                type: TextButton.Tonal
                disabled: root.page <= 1 || LiveWallpaper.workshopLoading
                onClicked: {
                    root.page--;
                    root.load();
                    root.flickable.contentY = 0;
                }
            }

            StyledText {
                text: Tr.tr("Page %1 of %2").arg(root.page).arg(root.pages)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            TextButton {
                text: Tr.tr("Next")
                type: TextButton.Tonal
                disabled: root.page >= root.pages || LiveWallpaper.workshopLoading
                onClicked: {
                    root.page++;
                    root.load();
                    root.flickable.contentY = 0;
                }
            }
        }

        // ---- An item's details ----------------------------------------

        ColumnLayout {
            id: details

            readonly property var it: root.selected ? Object.assign({}, root.selected, LiveWallpaper.workshopItem?.id === root.selected.id ? LiveWallpaper.workshopItem : {}) : null
            readonly property var mine: it ? LiveWallpaper.wallpapers.find(w => w.id === it.id) : null

            Layout.fillWidth: true
            visible: !!root.selected
            spacing: Tokens.spacing.medium

            TextButton {
                text: Tr.tr("Back to the Workshop")
                type: TextButton.Text
                onClicked: root.selected = null
            }

            ClipRect {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(width * 9 / 16, 480)
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh

                AnimatedImage {
                    anchors.fill: parent
                    source: details.it?.previewFull ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    playing: root.visible
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: details.it?.title ?? ""
                        font: Tokens.font.title.large
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !!details.it?.author
                        text: Tr.tr("by %1").arg(details.it?.author ?? "")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                    }

                    RowLayout {
                        spacing: Tokens.spacing.small

                        Stars {
                            rating: details.it?.rating ?? -1
                        }

                        StyledText {
                            text: (details.it?.rating ?? -1) < 0 ? Tr.tr("Not enough ratings yet") : Tr.tr("%1 ratings").arg(root.count(details.it?.votes ?? 0))
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.medium
                        }
                    }
                }

                ColumnLayout {
                    spacing: Tokens.spacing.small

                    TextButton {
                        Layout.fillWidth: true
                        text: details.mine ? Tr.tr("Use it") : Tr.tr("Subscribe in Steam")
                        type: TextButton.Filled
                        onClicked: {
                            if (details.mine) {
                                root.nState.selectedLiveWallpaper = details.mine;
                                root.nState.openSubPage(5);
                            } else {
                                LiveWallpaper.openInSteam(details.it.id);
                            }
                        }
                    }

                    TextButton {
                        Layout.fillWidth: true
                        text: Tr.tr("Copy link")
                        type: TextButton.Tonal
                        onClicked: Quickshell.clipboardText = `https://steamcommunity.com/sharedfiles/filedetails/?id=${details.it.id}`
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !details.mine
                text: Tr.tr("Subscribe on its page in Steam: the download then shows up among your wallpapers by itself.")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }

            // Stats, like the app's details panel
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Tokens.spacing.large
                rowSpacing: Tokens.spacing.extraSmall

                Repeater {
                    model: details.it ? [[Tr.tr("Subscribers"), root.count(details.it.subscriptions)], [Tr.tr("Favourites"), root.count(details.it.favorited)], [Tr.tr("File size"), root.size(details.it.size)], [Tr.tr("Updated"), details.it.updated ? new Date(details.it.updated * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : "—"]].concat(details.it.views ? [[Tr.tr("Views"), root.count(details.it.views)]] : []) : []

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData[0]
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }

                        StyledText {
                            text: modelData[1]
                            font: Tokens.font.body.small
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: (details.it?.tags ?? []).filter(t => t !== "Wallpaper")

                    StyledRect {
                        required property string modelData

                        implicitWidth: tagText.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: tagText.implicitHeight + Tokens.padding.small
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        StyledText {
                            id: tagText

                            anchors.centerIn: parent
                            text: parent.modelData
                            font: Tokens.font.label.medium
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: LiveWallpaper.workshopItemLoading ? Tr.tr("Loading the description…") : (details.it?.description ?? "").replace(/\[\/?[a-z0-9*]+(=[^\]]*)?\]/gi, "")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            text: Tr.tr("Steam has to be running and signed in; Wallpaper Engine has to be in your Steam library.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component Badge: StyledRect {
        property alias text: badgeText.text

        anchors.margins: 6
        implicitWidth: badgeText.implicitWidth + Tokens.padding.small * 2
        implicitHeight: badgeText.implicitHeight + 4
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary

        StyledText {
            id: badgeText

            anchors.centerIn: parent
            color: Colours.palette.m3onPrimary
            font: Tokens.font.label.small
        }
    }

    // Steam's star rating (0-5; -1: not enough ratings, hidden on a card)
    component Stars: StyledRect {
        id: stars

        property int rating: -1
        property bool overlay

        visible: rating >= 0 || !overlay
        implicitWidth: starRow.implicitWidth + (overlay ? Tokens.padding.small * 2 : 0)
        implicitHeight: starRow.implicitHeight + (overlay ? 4 : 0)
        radius: Tokens.rounding.full
        color: overlay ? Qt.alpha(Colours.palette.m3scrim, 0.55) : "transparent"

        Row {
            id: starRow

            anchors.centerIn: parent

            Repeater {
                model: 5

                MaterialIcon {
                    required property int index

                    text: "star"
                    fill: index < stars.rating ? 1 : 0
                    color: index < stars.rating ? "#ffc107" : (stars.overlay ? "white" : Colours.palette.m3outline)
                    fontStyle: Tokens.font.icon.small
                }
            }
        }
    }
}
