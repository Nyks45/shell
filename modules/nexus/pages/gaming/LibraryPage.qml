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
    property string searchQuery: ""
    property string sortBy: "name" // "name", "launcher", "custom"
    property bool adding
    // The game being added
    property string addTitle
    property string addExe
    property string addLauncher: "faugus"
    property string addProton
    // Install the usual runtimes (Visual C++, DirectX) into a new Windows game's prefix
    property bool addRuntimes: true
    // The added games' runtimes, by name (Games.runtimes)
    readonly property var runtimeRows: Object.values(Games.runtimes).sort((a, b) => a.title.localeCompare(b.title))
    readonly property var missingRows: runtimeRows.filter(r => r.missing.length > 0 && r.canInstall)

    function ownCount(g: var): int {
        return Object.keys(g.env ?? {}).length + (g.mangohud ? 1 : 0) + (g.perf ? 1 : 0);
    }

    readonly property var shown: {
        const q = searchQuery.trim().toLowerCase();
        const filtered = Games.games.filter(g => (filter === "all" || g.launcher === filter) && (!q || (g.title ?? "").toLowerCase().includes(q)));
        return [...filtered].sort((a, b) => {
            if (sortBy === "launcher")
                return (a.launcher ?? "").localeCompare(b.launcher ?? "") || (a.title ?? "").localeCompare(b.title ?? "");
            if (sortBy === "custom")
                return ownCount(b) - ownCount(a) || (a.title ?? "").localeCompare(b.title ?? "");
            return (a.title ?? "").localeCompare(b.title ?? "");
        });
    }
    readonly property var addChoices: (Games.launchers[addLauncher]?.choices ?? []).filter(c => c[0] !== "Linux-Native")

    function protonLabel(g: var): string {
        if (g.proton === null || g.proton === undefined)
            return "";
        const l = Games.launchers[g.settingsLauncher || g.launcher];
        const c = (l?.choices ?? []).find(x => x[0] === g.proton);
        if (g.proton)
            return c ? c[1] : g.proton.split("/").pop();
        return l?.default ? Tr.tr("default (%1)").arg(l.default) : Tr.tr("default Proton");
    }

    title: Tr.tr("Library")

    Component.onCompleted: {
        Games.load();
        Games.loadRuntimes();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // A game added or removed: its runtimes read again
        Connections {
            function onStampChanged(): void {
                Games.loadRuntimes();
            }

            target: Games
        }

        // A launcher installing or adding a game shows it here (checked while shown)
        Timer {
            running: root.visible
            repeat: true
            interval: 3000
            onTriggered: Games.check()
        }

        TextFieldRow {
            Layout.bottomMargin: Tokens.spacing.small
            label: Tr.tr("Search")
            placeholderText: Tr.tr("Filter games by name")
            onValueEdited: v => root.searchQuery = v
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
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

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: Games.games.length > 1
            spacing: Tokens.spacing.small

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: Tr.tr("Sort:")
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
                rightPadding: Tokens.padding.extraSmall
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [["name", Tr.tr("Name")], ["launcher", Tr.tr("Launcher")], ["custom", Tr.tr("Custom settings")]]

                    TextButton {
                        required property var modelData

                        text: modelData[1]
                        isToggle: true
                        followChecked: true
                        checked: root.sortBy === modelData[0]
                        type: TextButton.Tonal
                        onClicked: root.sortBy = modelData[0]
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !Games.loaded || Games.games.length === 0 || root.shown.length === 0
            text: !Games.loaded ? Tr.tr("Reading the launchers…") : Games.games.length === 0 ? Tr.tr("No games yet: install one in Steam, or add one below") : Tr.tr("No games match your filter.")
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

                            text: [
                                row.modelData.viaLauncher
                                    ? Tr.tr("%1 (via %2)").arg(Games.launcherNames[row.modelData.launcher] ?? row.modelData.launcher).arg(Games.launcherNames[row.modelData.viaLauncher] ?? row.modelData.viaLauncher)
                                    : row.modelData.shortcut ? Tr.tr("Steam (added)") : Games.launcherNames[row.modelData.launcher],
                                root.protonLabel(row.modelData),
                                row.modelData.state === "updating" ? Tr.tr("downloading or updating") : row.modelData.state === "hidden" ? Tr.tr("hidden in Faugus") : "",
                                Games.hasPending(row.modelData.key) ? Tr.tr("changes not saved yet") : "",
                                own ? (own === 1 ? Tr.tr("1 own setting") : Tr.tr("%1 own settings").arg(own)) : ""
                            ].filter(s => s).join(" · ")
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

        // The usual runtimes of the Windows games added by hand: Steam installs them for its
        // own games (its "Steamworks Common Redistributables"); these start without them
        SectionHeader {
            visible: root.runtimeRows.length > 0
            icon: "deployed_code"
            text: Tr.tr("Game runtimes")
            subtext: Tr.tr("Visual C++ (2005 to 2022) and DirectX (June 2010), what most Windows games expect. Steam installs them for its own games; games added by hand start without them.")
        }

        Repeater {
            model: root.runtimeRows

            RequirementRow {
                id: rtRow

                required property var modelData
                readonly property string what: Games.runtimesWhat(modelData.title)
                readonly property bool busy: Admin.jobs.some(j => j.what === what)
                // The helper's last line while installing ("Installing Visual C++ 2010 (3 of 7)")
                readonly property string progress: (Admin.outputOf(what).trim().split("\n").pop() ?? "").slice(0, 120)

                Layout.fillWidth: true
                neutral: true
                icon: modelData.missing.length === 0 ? "check_circle" : "deployed_code"
                text: modelData.title
                subtext: busy ? (progress || Tr.tr("Installing…")) : modelData.missing.length === 0 ? Tr.tr("All installed") : !modelData.canInstall ? Tr.tr("Its Proton/Wine version isn't installed: pick one in the game's settings") : (modelData.prefixExists ? Tr.tr("Missing: %1") : Tr.tr("Not started yet · missing: %1")).arg(modelData.missing.join(", "))
                actionText: !busy && modelData.missing.length > 0 && modelData.canInstall ? Tr.tr("Install") : ""
                onAction: Games.installRuntimes(modelData.key, modelData.title)
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: root.missingRows.length > 1
            icon: "download"
            text: Tr.tr("Install for all (%1 games)").arg(root.missingRows.length)
            subtext: Tr.tr("One after another; the first downloads the installers (about 250 MB), the rest reuse them")
            onClicked: {
                for (const r of root.missingRows)
                    Games.installRuntimes(r.key, r.title);
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
                root.addRuntimes = true;
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

        ToggleRow {
            Layout.topMargin: Tokens.spacing.small
            visible: root.adding && (!root.addExe || /\.(exe|msi|bat|lnk)$/i.test(root.addExe))
            text: Tr.tr("Install the usual runtimes")
            subtext: Tr.tr("Visual C++ and DirectX into its prefix, right after adding it (a few minutes)")
            checked: root.addRuntimes
            onToggled: root.addRuntimes = checked
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
                    proton: root.addProton,
                    runtimes: root.addRuntimes
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
