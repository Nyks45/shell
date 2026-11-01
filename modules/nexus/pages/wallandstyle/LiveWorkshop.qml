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

// The Steam Workshop for Wallpaper Engine: trending, popular, newest or a
// search (its public listing, rated Everyone). Subscribing happens in Steam,
// which downloads the wallpaper; it then shows up among yours.
PageBase {
    id: root

    property string sort: "trend"
    property string kind
    property string search
    property int page: 1
    readonly property var installed: new Set(LiveWallpaper.wallpapers.map(w => w.id))

    function load(): void {
        LiveWallpaper.loadWorkshop(sort, page, kind, search);
    }

    Component.onCompleted: load()

    title: Tr.tr("Steam Workshop")
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                Layout.fillWidth: true
                placeholderText: Tr.tr("Search the Workshop")
                onAccepted: {
                    root.search = text.trim();
                    root.page = 1;
                    root.load();
                }
            }

            Repeater {
                model: [
                    {
                        value: "trend",
                        text: Tr.tr("Trending")
                    },
                    {
                        value: "popular",
                        text: Tr.tr("Popular")
                    },
                    {
                        value: "recent",
                        text: Tr.tr("Newest")
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
                        root.page = 1;
                        root.load();
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: [
                    {
                        value: "",
                        text: Tr.tr("All")
                    },
                    {
                        value: "Scene",
                        text: Tr.tr("Scenes")
                    },
                    {
                        value: "Video",
                        text: Tr.tr("Videos")
                    },
                    {
                        value: "Web",
                        text: Tr.tr("Web")
                    }
                ]

                TextButton {
                    required property var modelData

                    text: modelData.text
                    isToggle: true
                    checked: root.kind === modelData.value
                    type: TextButton.Tonal
                    onClicked: {
                        root.kind = modelData.value;
                        root.page = 1;
                        root.load();
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: LiveWallpaper.workshopLoading ? Tr.tr("Loading…") : Tr.tr("Page %1").arg(root.page)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
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
            opacity: LiveWallpaper.workshopLoading ? 0.5 : 1
            columns: Math.max(2, Math.floor((width + columnSpacing) / (180 + columnSpacing)))
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
                    implicitHeight: itemCol.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainer

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: {
                            const mine = LiveWallpaper.wallpapers.find(w => w.id === item.modelData.id);
                            if (mine) {
                                root.nState.selectedLiveWallpaper = mine;
                                root.nState.openSubPage(5);
                            } else {
                                LiveWallpaper.openInSteam(item.modelData.id);
                            }
                        }
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
                            }

                            StyledRect {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                visible: item.have
                                implicitWidth: haveText.implicitWidth + Tokens.padding.small * 2
                                implicitHeight: haveText.implicitHeight + 4
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primary

                                StyledText {
                                    id: haveText

                                    anchors.centerIn: parent
                                    text: Tr.tr("Yours")
                                    color: Colours.palette.m3onPrimary
                                    font: Tokens.font.label.small
                                }
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
                            text: item.have ? Tr.tr("Click to use it") : Tr.tr("Click to subscribe in Steam")
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

            TextButton {
                text: Tr.tr("Next")
                type: TextButton.Tonal
                disabled: (LiveWallpaper.workshopPage.items ?? []).length < 30 || LiveWallpaper.workshopLoading
                onClicked: {
                    root.page++;
                    root.load();
                    root.flickable.contentY = 0;
                }
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
}
