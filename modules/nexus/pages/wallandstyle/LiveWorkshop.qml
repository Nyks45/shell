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
// from here once signed in to Steam (QR sign-in; the tokens stay in the
// keyring, see assets/live-wallpaper-steam.py), or on the item's page in
// Steam; Steam downloads it and it then shows up among yours.
PageBase {
    id: root

    // "browse" (the Workshop) or "mine" (your Workshop wallpapers)
    property string tab: "browse"
    readonly property var mineList: LiveWallpaper.wallpapers.filter(w => w.source === "workshop")
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

    // One of yours, as a Workshop entry (its stats load with the details)
    function openMine(w: var): void {
        open({
            id: w.id,
            title: w.title,
            preview: w.preview,
            previewFull: w.preview,
            tags: w.tags,
            mine: true
        });
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

    Component.onCompleted: {
        load();
        LiveWallpaper.steamStatus();
    }

    // Back (mouse button, header arrow) from an item's details: to the list
    onSelectedChanged: nState.backHandler = selected ? (() => {
                selected = null;
                return true;
            }) : null
    Component.onDestruction: {
        if (nState?.backHandler)
            nState.backHandler = null;
    }

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

        // Signed in done: close the sign-in panel after a moment
        Timer {
            running: LiveWallpaper.steamLogin?.state === "done"
            interval: 1500
            onTriggered: LiveWallpaper.steamLogin = null
        }

        // ---- Steam account -------------------------------------------

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: accountCol.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: accountCol

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: LiveWallpaper.steamSignedIn ? "account_circle" : "login"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: LiveWallpaper.steamSignedIn ? Tr.tr("Signed in to Steam as %1").arg(LiveWallpaper.steamAccount || "?") : Tr.tr("Sign in to Steam to subscribe right here")
                        font: Tokens.font.body.medium
                        wrapMode: Text.WordWrap
                    }

                    TextButton {
                        visible: !LiveWallpaper.steamLogin
                        text: LiveWallpaper.steamSignedIn ? Tr.tr("Sign out") : Tr.tr("Sign in")
                        type: LiveWallpaper.steamSignedIn ? TextButton.Text : TextButton.Filled
                        onClicked: LiveWallpaper.steamSignedIn ? LiveWallpaper.steamLogout() : LiveWallpaper.steamStartLogin()
                    }
                }

                // QR sign-in
                RowLayout {
                    Layout.fillWidth: true
                    visible: !!LiveWallpaper.steamLogin
                    spacing: Tokens.spacing.large

                    ClipRect {
                        implicitWidth: 180
                        implicitHeight: 180
                        radius: Tokens.rounding.medium
                        color: "white"
                        visible: !!LiveWallpaper.steamLogin?.qr && ["scan", "confirm"].includes(LiveWallpaper.steamLogin?.state)

                        Image {
                            anchors.fill: parent
                            source: LiveWallpaper.steamLogin?.qr ? `file://${LiveWallpaper.steamLogin.qr}` : ""
                            cache: false
                            smooth: false
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const st = LiveWallpaper.steamLogin?.state ?? "";
                                return st === "starting" ? Tr.tr("Asking Steam for a sign-in code…") : st === "scan" ? Tr.tr("Open the Steam app on your phone, tap the shield (Steam Guard) and scan this code.") : st === "confirm" ? Tr.tr("Now approve the sign-in on your phone.") : st === "done" ? Tr.tr("Signed in.") : st === "expired" ? Tr.tr("The code expired. Try again.") : Tr.tr("Couldn't sign in: %1").arg(LiveWallpaper.steamLogin?.error ?? "");
                            }
                            font: Tokens.font.body.medium
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("The sign-in stays on this PC, in your keyring, and is only sent to Steam. Sign out deletes it.")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            spacing: Tokens.spacing.small

                            TextButton {
                                visible: ["expired", "error"].includes(LiveWallpaper.steamLogin?.state ?? "")
                                text: Tr.tr("Try again")
                                type: TextButton.Tonal
                                onClicked: LiveWallpaper.steamStartLogin()
                            }

                            TextButton {
                                text: Tr.tr("Cancel")
                                type: TextButton.Text
                                onClicked: LiveWallpaper.steamCancelLogin()
                            }
                        }
                    }
                }
            }
        }

        // ---- Tabs ------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            visible: !root.selected
            spacing: Tokens.spacing.small

            TextButton {
                text: Tr.tr("Browse")
                isToggle: true
                checked: root.tab === "browse"
                type: TextButton.Tonal
                onClicked: root.tab = "browse"
            }

            TextButton {
                text: Tr.tr("Subscribed (%1)").arg(root.mineList.length)
                isToggle: true
                checked: root.tab === "mine"
                type: TextButton.Tonal
                onClicked: root.tab = "mine"
            }
        }

        // ---- Your Workshop wallpapers ----------------------------------

        GridLayout {
            Layout.fillWidth: true
            visible: !root.selected && root.tab === "mine"
            columns: Math.max(2, Math.floor((width + columnSpacing) / (190 + columnSpacing)))
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
                model: root.tab === "mine" ? root.mineList : []

                StyledRect {
                    id: mineCard

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: mineCol.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainer

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: root.openMine(mineCard.modelData)
                    }

                    ColumnLayout {
                        id: mineCol

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
                                source: mineCard.modelData.preview
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 800
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: mineCard.modelData.title
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${mineCard.modelData.type} · ${root.size(mineCard.modelData.size)}`
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ---- Browsing --------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            visible: !root.selected && root.tab === "browse"
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
            visible: !root.selected && !root.search && root.tab === "browse"
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
            visible: !root.selected && !root.search && root.sort === "trend" && root.tab === "browse"
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
            visible: !root.selected && root.showFilters && root.tab === "browse"
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

                // Same switch as on the live wallpapers page
                TextButton {
                    text: Tr.tr("Show mature wallpapers")
                    isToggle: true
                    checked: root.showMature
                    type: TextButton.Tonal
                    onClicked: {
                        LiveWallpaper.setQuiet("showMature", !root.showMature);
                        // Turned off: drop a mature age filter too
                        if (root.showMature && root.chosen["Age Rating"]) {
                            const c = Object.assign({}, root.chosen);
                            delete c["Age Rating"];
                            root.chosen = c;
                        }
                        Qt.callLater(root.reload);
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
            visible: !root.selected && root.tab === "browse"

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
            visible: !root.selected && root.tab === "browse"
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
                        id: itemState

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
                                sourceSize.width: 800
                            }

                            // Hovered: its animated preview, like Wallpaper Engine's grid
                            // (only this card's, so 30 GIFs never play at once)
                            Loader {
                                anchors.fill: parent
                                active: itemState.containsMouse && item.modelData.previewFull.length > 0
                                sourceComponent: AnimatedImage {
                                    source: item.modelData.previewFull
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    playing: true
                                }
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
            visible: !root.selected && root.tab === "browse"
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
            // Downloading into the library (DepotDownloader), this item
            readonly property var dl: it && LiveWallpaper.download?.id === it.id ? LiveWallpaper.download : null
            readonly property bool downloading: !!dl && ["starting", "qr", "progress"].includes(dl.state)

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
                        // Yours (no Steam rating in its details): no stars
                        visible: typeof details.it?.rating === "number"
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
                        text: details.mine ? Tr.tr("Use it") : details.downloading ? Tr.tr("Downloading…") : Tr.tr("Subscribe")
                        type: TextButton.Filled
                        disabled: details.downloading
                        onClicked: {
                            if (details.mine) {
                                root.nState.selectedLiveWallpaper = details.mine;
                                root.nState.openSubPage(5);
                            } else {
                                LiveWallpaper.getWallpaper(details.it.id);
                            }
                        }
                    }

                    TextButton {
                        Layout.fillWidth: true
                        visible: details.mine?.source === "workshop"
                        text: Tr.tr("Unsubscribe")
                        type: TextButton.Tonal
                        onClicked: {
                            LiveWallpaper.removeWallpaper(details.it.id);
                            root.selected = null;
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

            // The download: the one-time sign-in code, progress, errors
            StyledRect {
                Layout.fillWidth: true
                visible: !!details.dl && details.dl.state !== "done"
                implicitHeight: dlRow.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainer

                RowLayout {
                    id: dlRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.large

                    StyledRect {
                        visible: details.dl?.state === "qr"
                        implicitWidth: 196
                        implicitHeight: 196
                        radius: Tokens.rounding.medium
                        color: "white"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 12
                            source: details.dl?.qr ? `file://${details.dl.qr}` : ""
                            cache: false
                            smooth: false
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const d = details.dl;
                                return !d ? "" : d.state === "starting" ? Tr.tr("Connecting to Steam…") : d.state === "qr" ? Tr.tr("First download: sign the downloader in once. Open the Steam app on your phone, tap the shield (Steam Guard) and scan this code.") : d.state === "progress" ? Tr.tr("Downloading… %1%").arg(Math.round(d.percent ?? 0)) : Tr.tr("Couldn't download it: %1").arg(d.error ?? "");
                            }
                            font: Tokens.font.body.medium
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: details.dl?.state === "qr"
                            text: Tr.tr("Only once: the download session is kept in your keyring like the other sign-in, and is on disk only while a download runs.")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            spacing: Tokens.spacing.small

                            TextButton {
                                visible: details.dl?.state === "error"
                                text: Tr.tr("Try again")
                                type: TextButton.Tonal
                                onClicked: LiveWallpaper.getWallpaper(details.it.id)
                            }

                            TextButton {
                                text: details.downloading ? Tr.tr("Cancel") : Tr.tr("Close")
                                type: TextButton.Text
                                onClicked: LiveWallpaper.cancelDownload()
                            }
                        }
                    }
                }
            }

            // Steam's answer when subscribing failed
            StyledText {
                Layout.fillWidth: true
                visible: !!LiveWallpaper.steamError
                text: LiveWallpaper.steamError
                color: Colours.palette.m3error
                font: Tokens.font.body.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: !details.mine && !details.dl
                text: LiveWallpaper.steamSignedIn ? Tr.tr("Subscribe downloads it into your library and adds it to your Steam subscriptions.") : Tr.tr("Subscribe downloads it into your library. Sign in above to also add it to your Steam subscriptions.")
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
            text: Tr.tr("Downloads need a Steam account that owns Wallpaper Engine; neither the Steam client nor Wallpaper Engine has to be installed.")
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
