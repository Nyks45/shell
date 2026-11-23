pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.dashboard as Dashboard
import qs.modules.launcher.services

// The centred launchers (Config.launcher.style):
//  "grid"      — the search over a grid of apps
//  "wallpaper" — HyDE-like: the current wallpaper beside the search and the list of apps
// Actions (the action prefix) and the wallpaper picker use the usual list in both.
Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    // How far it's open (0..1, the wrapper's): the opening animations of each style
    property real open: 1
    // The wallpaper style: picking a wallpaper (its picker in place of the search and list)
    property bool picking

    readonly property string style: Config.launcher.style
    readonly property bool withWallpaper: style === "wallpaper"
    // The grid for apps; anything after the action prefix in the list
    readonly property bool gridShown: style === "grid" && !search.text.toLowerCase().startsWith(GlobalConfig.launcher.actionPrefix.toLowerCase())

    readonly property int padding: Tokens.padding.large
    readonly property real bodyWidth: withWallpaper ? 500 : 6 * 104
    // (the grid: exactly four rows under the search, none cut off at its foot)
    readonly property real bodyHeight: withWallpaper ? Math.min(root.maxHeight - padding * 2, 440) : search.implicitHeight + Tokens.spacing.medium + grid.cellHeight * 4
    readonly property real wallWidth: 290
    // The wallpaper style opens out of its wallpaper: the width it starts from
    readonly property real collapsedWidth: wallWidth + padding * 2
    // The right side comes in after the wallpaper, sliding out from under it
    readonly property real bodyIn: withWallpaper ? Math.min(1, Math.max(0, (open - 0.45) / 0.45)) : 1

    // (the search is hidden while picking a wallpaper: Escape still closes it)
    onPickingChanged: {
        if (picking)
            forceActiveFocus();
        else
            search.forceActiveFocus();
    }
    Keys.onEscapePressed: {
        if (picking)
            picking = false;
        else
            screenState.launcher = false;
    }

    implicitWidth: (withWallpaper ? wallWidth + padding : 0) + bodyWidth + padding * 2
    implicitHeight: bodyHeight + padding * 2

    // The wallpaper (HyDE-like), with the time over its foot
    ClipRect {
        id: wall

        visible: root.withWallpaper
        x: root.padding
        y: root.padding
        implicitWidth: root.wallWidth
        implicitHeight: root.bodyHeight
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.6)

        // The picture, or the live wallpaper's still (the renderer's saved frame) over it
        Image {
            anchors.fill: parent
            source: root.withWallpaper && Wallpapers.current ? `file://${Wallpapers.current}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 640
        }

        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: root.withWallpaper && LiveWallpaper.currentInfo && LiveWallpaper.currentFrame ? `file://${LiveWallpaper.currentFrame}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 640
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.55
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("black", 0.55)
                }
            }
        }

        // Change it: the picker (live wallpapers and pictures) on the right; again: back
        StyledRect {
            id: change

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.padding.medium
            implicitWidth: changeRow.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: changeRow.implicitHeight + Tokens.padding.small * 2
            radius: height / 2
            color: root.picking ? Colours.palette.m3primary : Qt.alpha("black", 0.45)

            StateLayer {
                radius: change.height / 2
                color: root.picking ? Colours.palette.m3onPrimary : "white"
                onClicked: root.picking = !root.picking
            }

            Row {
                id: changeRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.picking ? "check" : "wallpaper"
                    color: root.picking ? Colours.palette.m3onPrimary : "white"
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.picking ? Tr.tr("Done") : Tr.tr("Change")
                    color: root.picking ? Colours.palette.m3onPrimary : "white"
                    font: Tokens.font.label.medium
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.large

            StyledText {
                text: Time.format("hh:mm")
                color: "white"
                font: Tokens.font.headline.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: Time.format("dddd, d MMMM")
                color: Qt.alpha("white", 0.8)
                font: Tokens.font.label.large
            }
        }
    }

    Item {
        id: body

        // (the wallpaper style: slides out from under the wallpaper as it opens)
        x: root.padding + (root.withWallpaper ? root.wallWidth + root.padding : 0) - (1 - root.bodyIn) * 40
        y: root.padding
        width: root.bodyWidth
        height: root.bodyHeight
        opacity: root.bodyIn
        visible: !root.picking

        SearchBar {
            id: search

            objectName: "launcherSearch"

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            topPadding: Tokens.padding.medium
            bottomPadding: Tokens.padding.medium
            bg.color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)

            placeholderText: root.gridShown || root.withWallpaper ? Tr.tr("Search apps, or \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix) : Tr.tr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

            onAccepted: {
                if (root.gridShown) {
                    grid.launchCurrent();
                    return;
                }
                const currentItem = list.currentList?.currentItem;
                if (!currentItem)
                    return;
                if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.toLowerCase().startsWith(GlobalConfig.launcher.actionPrefix.toLowerCase())) {
                    if (text.toLowerCase().startsWith(`${GlobalConfig.launcher.actionPrefix.toLowerCase()}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.screenState.launcher = false;
                }
            }

            Keys.onUpPressed: root.gridShown ? grid.moveCurrentIndexUp() : list.currentList?.decrementCurrentIndex()
            Keys.onDownPressed: root.gridShown ? grid.moveCurrentIndexDown() : list.currentList?.incrementCurrentIndex()
            Keys.onEscapePressed: root.screenState.launcher = false

            // (in the grid, left/right move between apps while the cursor is at the text's end)
            Keys.onPressed: event => {
                if (root.gridShown && cursorPosition === text.length) {
                    if (event.key === Qt.Key_Right) {
                        grid.moveCurrentIndexRight();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Left && text.length === 0) {
                        grid.moveCurrentIndexLeft();
                        event.accepted = true;
                        return;
                    }
                }
                if (event.key === Qt.Key_Tab) {
                    if (root.gridShown)
                        grid.moveCurrentIndexRight();
                    else
                        list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    if (root.gridShown)
                        grid.moveCurrentIndexLeft();
                    else
                        list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                function onLauncherChanged(): void {
                    if (!root.screenState.launcher)
                        search.text = "";
                }

                function onSessionChanged(): void {
                    if (!root.screenState.session)
                        search.forceActiveFocus();
                }

                target: root.screenState
            }
        }

        // The apps as a grid
        AppGrid {
            id: grid

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: search.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: Tokens.spacing.medium

            visible: root.gridShown
            query: root.gridShown ? search.text : "\u0000"
            screenState: root.screenState
            open: root.open
        }

        // The list (the wallpaper style's apps; the actions and the wallpaper picker in both)
        Item {
            id: listArea

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: search.bottom
            anchors.bottom: parent.bottom
            anchors.topMargin: Tokens.spacing.medium
            visible: !root.gridShown

            ContentList {
                id: list

                // (its own anchors centre it at its item width: here it fills the column)
                anchors.bottom: undefined
                anchors.horizontalCenter: undefined
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                content: root
                screenState: root.screenState
                panels: root.panels
                maxHeight: listArea.height
                search: search
                padding: root.padding
                rounding: Tokens.rounding.large
            }
        }

        StyledText {
            anchors.centerIn: grid
            visible: root.gridShown && grid.count === 0
            text: Tr.tr("No apps found")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }
    }

    // The wallpaper style's picker (the island's wallpapers page): in place of the search and list
    Loader {
        x: body.x
        y: body.y
        width: body.width
        height: body.height
        active: root.picking
        opacity: root.picking ? 1 : 0

        sourceComponent: Dashboard.WallpapersTab {
            screenState: root.screenState
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Connections {
        function onLauncherChanged(): void {
            if (!root.screenState.launcher)
                root.picking = false;
        }

        target: root.screenState
    }
}
