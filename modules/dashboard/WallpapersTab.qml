pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Multimedia
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

// Dashboard > Wallpapers: pick a live wallpaper (your Wallpaper Engine library, most recently
// used first; shown first) or a picture (the wallpaper folder). A click applies it; Random picks one of
// the kind shown; the settings button opens Wallpaper & style for everything else.
Item {
    id: root

    required property ScreenState screenState

    // "live" (first) or "pictures"
    property string kind: "live"

    readonly property var pictures: Wallpapers.list.filter(w => !w.isDir).slice().sort((a, b) => a.name.localeCompare(b.name))
    readonly property var lives: {
        const recent = LiveWallpaper.config.history ?? {};
        return LiveWallpaper.wallpapers.filter(w => LiveWallpaper.usable(w)).slice().sort((a, b) => (recent[b.path] ?? 0) - (recent[a.path] ?? 0) || a.title.localeCompare(b.title));
    }
    readonly property bool liveOn: !!LiveWallpaper.currentInfo

    implicitWidth: 620
    implicitHeight: 380

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "animated_images"
                text: Tr.tr("Live")
                type: IconTextButton.Tonal
                isRound: true
                checked: root.kind === "live"
                onClicked: root.kind = "live"
            }

            IconTextButton {
                icon: "image"
                text: Tr.tr("Pictures")
                type: IconTextButton.Tonal
                isRound: true
                checked: root.kind === "pictures"
                onClicked: root.kind = "pictures"
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: "shuffle"
                type: IconButton.Text
                onClicked: root.kind === "live" ? LiveWallpaper.random() : Wallpapers.setRandom()
            }

            IconButton {
                icon: "settings"
                type: IconButton.Text
                onClicked: {
                    root.screenState.dashboard = false;
                    WindowFactory.createAt("wallpaper", root.kind === "live" ? [4] : [1]);
                }
            }
        }

        GridView {
            id: grid

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Math.floor(width / 3)
            cellHeight: Math.floor(cellWidth * 9 / 16) + 30
            boundsBehavior: Flickable.StopAtBounds
            model: root.kind === "live" ? root.lives : root.pictures

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: grid
            }

            delegate: Item {
                id: cell

                required property var modelData

                readonly property bool live: root.kind === "live"
                readonly property string path: String(modelData.path ?? "")
                readonly property bool current: live ? (root.liveOn && LiveWallpaper.currentInfo?.path === path) : (!root.liveOn && Wallpapers.actualCurrent === path)

                width: grid.cellWidth
                height: grid.cellHeight

                ClipRect {
                    id: thumb

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 4
                    height: width * 9 / 16
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainerHigh

                    // A picture or a video (the settings' thumbnails; a video plays on hover)
                    Visual {
                        anchors.fill: parent
                        visible: !cell.live
                        source: cell.live ? "" : cell.path
                        fillMode: Image.PreserveAspectCrop
                        playing: thumbHover.hovered
                    }

                    Image {
                        anchors.fill: parent
                        visible: cell.live
                        source: {
                            const p = cell.live ? (cell.modelData.still || cell.modelData.preview || "") : "";
                            return p ? `file://${p}` : "";
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                    }

                    HoverHandler {
                        id: thumbHover
                    }

                    StyledRect {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Tokens.rounding.medium
                        border.width: cell.current ? 3 : 0
                        border.color: Colours.palette.m3primary
                    }

                    StateLayer {
                        radius: Tokens.rounding.medium
                        onClicked: {
                            if (cell.live)
                                LiveWallpaper.apply(cell.path, "*");
                            else
                                Wallpapers.setWallpaper(cell.path);
                        }
                    }
                }

                StyledText {
                    anchors.top: thumb.bottom
                    anchors.topMargin: 4
                    anchors.left: thumb.left
                    anchors.right: thumb.right
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.live ? (cell.modelData.title ?? "") : (cell.modelData.name ?? "")
                    color: cell.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: root.kind === "live" ? Tr.tr("No live wallpapers yet: get some in Wallpaper & style > Live") : Tr.tr("No pictures in the wallpaper folder")
                color: Colours.palette.m3outline
            }
        }
    }
}
