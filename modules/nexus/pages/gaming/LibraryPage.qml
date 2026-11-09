pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

// Every launcher's games in one list (Games service): a game installed in
// Steam or added in Faugus, Lutris or Heroic shows up by itself. A game
// opens its own page (GamePage: Proton, options, overlay); Windows games
// can be added to Steam (as a non-Steam game), Faugus or Lutris here.
PageBase {
    id: root

    property string filter: "all"
    property bool adding
    // The game being added
    property string addTitle
    property string addExe
    property string addLauncher: "faugus"
    property string addProton

    readonly property var shown: Games.games.filter(g => filter === "all" || g.launcher === filter)
    readonly property var addChoices: (Games.launchers[addLauncher]?.choices ?? []).filter(c => c[0] !== "Linux-Native")

    function protonLabel(g: var): string {
        if (g.proton === null || g.proton === undefined)
            return "";
        const l = Games.launchers[g.launcher];
        const c = (l?.choices ?? []).find(x => x[0] === g.proton);
        if (g.proton)
            return c ? c[1] : g.proton.split("/").pop();
        return l?.default ? Tr.tr("default (%1)").arg(l.default) : Tr.tr("default Proton");
    }

    title: Tr.tr("Library")

    Component.onCompleted: Games.load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // A launcher installing or adding a game shows it here (checked while shown)
        Timer {
            running: root.visible
            repeat: true
            interval: 3000
            onTriggered: Games.check()
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            Repeater {
                model: [["all", Tr.tr("All")], ...["steam", "lutris", "faugus", "heroic"].filter(l => Games.games.some(g => g.launcher === l)).map(l => [l, Games.launcherNames[l]])]

                TextButton {
                    required property var modelData

                    text: `${modelData[1]} ${modelData[0] === "all" ? Games.games.length : Games.games.filter(g => g.launcher === modelData[0]).length}`
                    isToggle: true
                    followChecked: true
                    checked: root.filter === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.filter = modelData[0]
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !Games.loaded || Games.games.length === 0
            text: Games.loaded ? Tr.tr("No games yet: install one in Steam, or add one below") : Tr.tr("Reading the launchers…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.shown

            ConnectedRect {
                id: row

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: rowL.implicitHeight + Tokens.padding.medium * 2

                StateLayer {
                    onClicked: {
                        root.nState.selectedGame = row.modelData.key;
                        root.nState.openSubPage(1);
                    }
                }

                RowLayout {
                    id: rowL

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    ClippingRectangle {
                        implicitWidth: 40
                        implicitHeight: 56
                        radius: Tokens.rounding.small
                        color: Colours.palette.m3surfaceContainerHighest

                        Image {
                            anchors.fill: parent
                            visible: !!row.modelData.cover
                            source: row.modelData.cover ? `file://${row.modelData.cover}` : ""
                            sourceSize.width: 80
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !row.modelData.cover
                            text: "sports_esports"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            readonly property int own: Object.keys(row.modelData.env).length + (row.modelData.mangohud ? 1 : 0) + (row.modelData.perf ? 1 : 0)

                            text: [row.modelData.shortcut ? Tr.tr("Steam (added)") : Games.launcherNames[row.modelData.launcher], root.protonLabel(row.modelData), row.modelData.state === "updating" ? Tr.tr("downloading or updating") : row.modelData.state === "hidden" ? Tr.tr("hidden in Faugus") : "", own ? (own === 1 ? Tr.tr("1 own setting") : Tr.tr("%1 own settings").arg(own)) : ""].filter(s => s).join(" · ")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    TextButton {
                        visible: row.modelData.state !== "updating"
                        text: Tr.tr("Play")
                        type: TextButton.Tonal
                        onClicked: Games.play(row.modelData)
                    }

                    MaterialIcon {
                        text: "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        // Adding a Windows game (Faugus or Lutris)
        SectionHeader {
            text: Tr.tr("Add a game")
        }

        RowButton {
            Layout.fillWidth: true
            visible: !root.adding
            icon: "add"
            text: Tr.tr("Add a game")
            subtext: Tr.tr("A game's program (a Windows .exe runs with Proton): added to Steam, Faugus or Lutris")
            onClicked: {
                root.addTitle = "";
                root.addExe = "";
                root.addProton = "";
                root.adding = true;
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: root.adding
            icon: "folder_open"
            text: root.addExe ? root.addExe.split("/").pop() : Tr.tr("Choose its program")
            subtext: root.addExe ? Paths.shortenHome(root.addExe) : Tr.tr("The game's .exe (or its installer, to install it first)")
            onClicked: exePicker.open()
        }

        TextFieldRow {
            visible: root.adding
            label: Tr.tr("Name")
            placeholderText: Tr.tr("The game's name")
            value: root.addTitle
            onValueEdited: v => root.addTitle = v
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.adding
            spacing: Tokens.spacing.small

            StyledText {
                text: Tr.tr("With:")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                topPadding: Tokens.padding.small
            }

            Repeater {
                model: ["steam", "faugus", "lutris"].filter(l => !!Games.launchers[l]?.installed)

                TextButton {
                    required property string modelData

                    text: Games.launcherNames[modelData]
                    isToggle: true
                    followChecked: true
                    checked: root.addLauncher === modelData
                    type: TextButton.Tonal
                    onClicked: {
                        root.addLauncher = modelData;
                        root.addProton = "";
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.adding && (!root.addExe || /\.(exe|msi|bat|lnk)$/i.test(root.addExe))
            spacing: Tokens.spacing.small

            StyledText {
                text: Tr.tr("Proton:")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                topPadding: Tokens.padding.small
            }

            TextButton {
                visible: root.addLauncher === "faugus"
                readonly property string def: Games.launchers.faugus?.default ?? ""

                text: !def ? Tr.tr("Faugus's default") : (Games.launchers.faugus.choices ?? []).some(c => c[0] === def) ? Tr.tr("Faugus's default (%1)").arg(def) : Tr.tr("Faugus's default (%1: not installed)").arg(def)
                isToggle: true
                followChecked: true
                checked: root.addProton === ""
                type: TextButton.Tonal
                onClicked: root.addProton = ""
            }

            Repeater {
                model: root.addChoices

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.addProton === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.addProton = modelData[0]
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: root.adding && Games.blocked(root.addLauncher)
            text: Tr.tr("%1 is open: close it first (it rewrites its game list when it quits).").arg(Games.launcherNames[root.addLauncher])
            wrapMode: Text.WordWrap
            color: Colours.palette.m3error
            font: Tokens.font.label.small
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.adding
            spacing: Tokens.spacing.small

            Item {
                Layout.fillWidth: true
            }

            TextButton {
                text: Tr.tr("Cancel")
                type: TextButton.Text
                onClicked: root.adding = false
            }

            TextButton {
                enabled: !!root.addExe && !!root.addTitle.trim() && !Games.blocked(root.addLauncher)
                text: Tr.tr("Add")
                type: TextButton.Filled
                onClicked: Games.add({
                    launcher: root.addLauncher,
                    title: root.addTitle.trim(),
                    exe: root.addExe,
                    proton: root.addProton
                }, ok => {
                    if (ok)
                        root.adding = false;
                })
            }
        }

        FileDialog {
            id: exePicker

            title: Tr.tr("The game's program")
            filterLabel: Tr.tr("Programs")
            filters: ["exe", "msi", "bat", "lnk", "sh", "x86_64", "AppImage"]
            onAccepted: path => {
                root.addExe = path;
                if (!root.addTitle) {
                    // A name from the folder it's in ("…/Hollow Knight/hollow_knight.exe")
                    const parts = path.split("/");
                    const dir = parts[parts.length - 2] ?? "";
                    root.addTitle = dir && !/^(bin|binaries|win64|x64|game)$/i.test(dir) ? dir : parts.pop().replace(/\.[^.]+$/, "");
                }
            }
        }
    }
}
