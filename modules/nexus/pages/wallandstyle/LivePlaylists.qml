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

// Live wallpaper playlists: wallpapers that take turns (Wallpaper Engine's
// format, in its config.json: the renderer switches them itself). Make one,
// pick its wallpapers, how often and in what order, and play it.
PageBase {
    id: root

    // The one being edited (a copy), or null for the list
    property var draft: null
    property string draftOriginal
    property string pickQuery
    readonly property var monitors: Hypr.monitors.values.map(m => m.name)

    function edit(pl: var): void {
        draft = pl ? JSON.parse(JSON.stringify(pl)) : {
            name: "",
            items: [],
            delay: 30,
            order: "sequential"
        };
        draftOriginal = pl?.name ?? "";
    }

    function toggleItem(path: string): void {
        const items = draft.items.includes(path) ? draft.items.filter(i => i !== path) : [...draft.items, path];
        draft = Object.assign({}, draft, {
            items
        });
    }

    readonly property bool nameOk: !!draft && draft.name.trim().length > 0 && draft.name.trim().length <= 50 && !LiveWallpaper.playlists.some(p => p.name === draft.name.trim() && p.name !== draftOriginal)

    // The editor is long, the list short: start each at the top
    readonly property bool editing: !!draft

    onEditingChanged: flickable.contentY = 0

    title: draft ? (draftOriginal ? Tr.tr("Edit playlist") : Tr.tr("New playlist")) : Tr.tr("Playlists")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // The list
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: !root.draft
            text: Tr.tr("Wallpapers that take turns, every so often, in order or shuffled.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: list

            model: root.draft ? [] : LiveWallpaper.playlists

            ConnectedRect {
                id: plRow

                required property var modelData
                required property int index
                readonly property var playingOn: Object.entries(LiveWallpaper.screens).filter(([, v]) => v === `playlist:${modelData.name}`).map(([k]) => k)

                Layout.fillWidth: true
                first: index === 0
                implicitHeight: plLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: plLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: plRow.playingOn.length ? "play_circle" : "playlist_play"
                        color: plRow.playingOn.length ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        fill: plRow.playingOn.length ? 1 : 0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: plRow.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: [Tr.trN("%n wallpaper", "%n wallpapers", plRow.modelData.items.length), Tr.tr("every %1 min").arg(plRow.modelData.delay), plRow.modelData.order === "random" ? Tr.tr("shuffled") : Tr.tr("in order"), plRow.playingOn.length ? Tr.tr("playing") : ""].filter(s => s).join(" · ")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        text: root.monitors.length > 1 ? Tr.tr("Play on all") : Tr.tr("Play")
                        type: TextButton.Tonal
                        disabled: plRow.modelData.items.length === 0
                        onClicked: LiveWallpaper.apply(`playlist:${plRow.modelData.name}`, "*")
                    }

                    Repeater {
                        model: root.monitors.length > 1 ? root.monitors : []

                        TextButton {
                            required property string modelData

                            text: modelData
                            type: TextButton.Text
                            disabled: plRow.modelData.items.length === 0
                            onClicked: LiveWallpaper.apply(`playlist:${plRow.modelData.name}`, modelData)
                        }
                    }

                    IconButton {
                        icon: "edit"
                        type: IconButton.Text
                        onClicked: root.edit(plRow.modelData)
                    }
                }
            }
        }

        RowButton {
            visible: !root.draft
            first: LiveWallpaper.playlists.length === 0
            last: true
            icon: "add"
            text: Tr.tr("New playlist")
            onClicked: root.edit(null)
        }

        // The editor
        TextFieldRow {
            visible: !!root.draft
            first: true
            label: Tr.tr("Name")
            value: root.draft?.name ?? ""
            errorText: root.draft && root.draft.name.trim() && !root.nameOk ? Tr.tr("Another playlist has this name") : ""
            onValueEdited: v => root.draft = Object.assign({}, root.draft, {
                    name: v
                })
        }

        StepperRow {
            visible: !!root.draft
            label: Tr.tr("Change every")
            subtext: Tr.tr("Minutes")
            value: root.draft?.delay ?? 30
            from: 1
            to: 1440
            stepSize: 5
            onMoved: v => root.draft = Object.assign({}, root.draft, {
                    delay: Math.max(1, Math.round(v))
                })
        }

        SelectRow {
            visible: !!root.draft
            last: true
            label: Tr.tr("Order")
            menuItems: [
                MenuItem {
                    text: Tr.tr("In order")
                    value: "sequential"
                },
                MenuItem {
                    text: Tr.tr("Shuffled")
                    value: "random"
                }
            ]
            active: menuItems.find(i => i.value === (root.draft?.order ?? "sequential")) ?? null
            onSelected: item => root.draft = Object.assign({}, root.draft, {
                    order: item.value
                })
        }

        SectionHeader {
            visible: !!root.draft
            text: Tr.tr("Wallpapers (%1 picked)").arg(root.draft?.items.length ?? 0)
        }

        StyledTextField {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.draft
            placeholderText: Tr.tr("Search by name or tag")
            onTextChanged: root.pickQuery = text
        }

        GridLayout {
            Layout.fillWidth: true
            visible: !!root.draft
            columns: Math.max(3, Math.floor((width + columnSpacing) / (140 + columnSpacing)))
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
                model: root.draft ? LiveWallpaper.wallpapers.filter(w => LiveWallpaper.usable(w) && (!root.pickQuery.trim() || `${w.title} ${w.tags.join(" ")}`.toLowerCase().includes(root.pickQuery.trim().toLowerCase()))) : []

                StyledRect {
                    id: pick

                    required property var modelData
                    readonly property bool picked: root.draft?.items.includes(modelData.path) ?? false

                    Layout.fillWidth: true
                    implicitHeight: pickCol.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.medium
                    color: picked ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                    border.width: picked ? 2 : 0
                    border.color: Colours.palette.m3primary

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: root.toggleItem(pick.modelData.path)
                    }

                    ColumnLayout {
                        id: pickCol

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        spacing: Tokens.spacing.extraSmall

                        ClipRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            radius: Tokens.rounding.small
                            color: Colours.tPalette.m3surfaceContainerHigh

                            Image {
                                anchors.fill: parent
                                source: pick.modelData.preview ? `file://${pick.modelData.preview}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 280
                            }

                            MaterialIcon {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                visible: pick.picked
                                text: "check_circle"
                                color: Colours.palette.m3primary
                                fill: 1
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: pick.modelData.title
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.topMargin: Tokens.spacing.medium
            visible: !!root.draft
            spacing: Tokens.spacing.small

            TextButton {
                text: Tr.trCtx("Save", "button")
                type: TextButton.Filled
                disabled: !root.nameOk || (root.draft?.items.length ?? 0) === 0
                onClicked: {
                    LiveWallpaper.savePlaylist(Object.assign({}, root.draft, {
                        name: root.draft.name.trim()
                    }), root.draftOriginal);
                    root.draft = null;
                }
            }

            TextButton {
                text: Tr.trCtx("Cancel", "button")
                type: TextButton.Text
                onClicked: root.draft = null
            }

            Item {
                Layout.fillWidth: true
            }

            TextButton {
                visible: !!root.draftOriginal
                text: Tr.trCtx("Delete", "button")
                type: TextButton.Text
                onClicked: {
                    LiveWallpaper.deletePlaylist(root.draftOriginal);
                    root.draft = null;
                }
            }
        }
    }
}
