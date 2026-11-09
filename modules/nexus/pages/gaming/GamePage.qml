pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// One game (nState.selectedGame, a Games key): which Proton runs it, its
// overlay and performance mode, and its own value for each option set for
// all games (Settings › Gaming › Game options). Saved where its launcher
// keeps them (Steam: its launch options; Lutris, Faugus, Heroic: the game's
// settings), so the launcher shows the same.
PageBase {
    id: root

    readonly property var game: Games.find(nState.selectedGame ?? "")
    readonly property var launcher: game ? Games.launchers[game.launcher] ?? {} : {}
    readonly property bool blocked: !!game && Games.blocked(game.launcher)
    readonly property string what: Tr.tr("Change %1's settings").arg(game?.title ?? "")
    readonly property bool busy: Admin.jobs.some(j => j.what === root.what)
    readonly property bool canChange: !!game && !blocked && !busy
    readonly property var choices: launcher.choices ?? []

    function change(c: var): void {
        Games.set(game.key, c, what);
    }

    function size(b: real): string {
        return b > 1073741824 ? `${(b / 1073741824).toFixed(1)} GB` : b > 0 ? `${Math.round(b / 1048576)} MB` : "";
    }

    title: game?.title ?? Tr.tr("Game")
    isSubPage: true

    Component.onCompleted: Games.check()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible
            repeat: true
            interval: 3000
            onTriggered: Games.check()
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !root.game
            text: Games.loaded ? Tr.tr("This game isn't in its launcher any more.") : Tr.tr("Reading the launchers…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        // The game: cover, launcher, where, play
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            visible: !!root.game
            spacing: Tokens.spacing.large

            ClippingRectangle {
                implicitWidth: 96
                implicitHeight: 136
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainerHighest

                Image {
                    anchors.fill: parent
                    visible: !!root.game?.cover
                    source: root.game?.cover ? `file://${root.game.cover}` : ""
                    sourceSize.width: 192
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !root.game?.cover
                    text: "sports_esports"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    text: root.game?.title ?? ""
                    font: Tokens.font.title.medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: [root.game?.shortcut ? Tr.tr("In Steam (added there as a non-Steam game)") : Tr.tr("In %1").arg(Games.launcherNames[root.game?.launcher] ?? ""), root.size(root.game?.size ?? 0), root.game?.state === "updating" ? Tr.tr("downloading or updating") : ""].filter(s => s).join(" · ")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.game?.path
                    text: Paths.shortenHome(root.game?.path ?? "")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small

                    TextButton {
                        visible: root.game?.state !== "updating"
                        text: Tr.tr("Play")
                        type: TextButton.Filled
                        onClicked: Games.play(root.game)
                    }

                    TextButton {
                        visible: !!root.game?.path
                        text: Tr.tr("Open folder")
                        type: TextButton.Tonal
                        onClicked: Quickshell.execDetached(["xdg-open", root.game.launcher === "faugus" || root.game.launcher === "lutris" && root.game.path.endsWith(".exe") ? root.game.path.replace(/\/[^/]*$/, "") : root.game.path])
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.blocked || root.busy
            text: root.busy ? Tr.tr("Saving…") : Tr.tr("%1 is open: close it to change this game's settings (it rewrites them when it quits).").arg(Games.launcherNames[root.game?.launcher] ?? "")
            wrapMode: Text.WordWrap
            color: root.busy ? Colours.palette.m3primary : Colours.palette.m3error
            font: Tokens.font.label.small
        }

        // Proton
        SectionHeader {
            first: true
            visible: !!root.game && root.game.proton !== null && root.game.proton !== undefined
            text: Tr.tr("Runs with")
        }

        Flow {
            Layout.fillWidth: true
            visible: !!root.game && root.game.proton !== null && root.game.proton !== undefined
            spacing: Tokens.spacing.small

            Repeater {
                // The game's current one too, if it isn't installed any more
                model: root.game && root.game.proton && !root.choices.some(c => c[0] === root.game.proton) ? [...root.choices, [root.game.proton, Tr.tr("%1 (not installed)").arg(root.game.proton.split("/").pop())]] : root.choices

                TextButton {
                    required property var modelData

                    enabled: root.canChange
                    text: modelData[0] === "" && root.launcher.default ? `${modelData[1]} (${root.launcher.default})` : modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: (root.game?.proton ?? "") === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.change({
                        proton: modelData[0]
                    })
                }
            }
        }

        // Overlay and performance
        SectionHeader {
            visible: !!root.game
            text: Tr.tr("While it runs")
        }

        ToggleRow {
            visible: !!root.game
            enabled: root.canChange
            text: Tr.tr("Overlay")
            subtext: Tr.tr("Frame rate and the rest (Gaming › Overlay); Shift (right) + F12 hides it")
            checked: !!root.game?.mangohud
            onToggled: root.change({
                mangohud: checked
            })
        }

        ToggleRow {
            visible: !!root.game && root.game.perf !== null && root.game.perf !== undefined
            enabled: root.canChange
            text: Tr.tr("Performance mode")
            subtext: Tr.tr("The performance power profile and the scheduler's Gaming mode while it runs (game-performance)")
            checked: !!root.game?.perf
            onToggled: root.change({
                perf: checked
            })
        }

        // Its own value for the options set for all games
        component OptionRow: ConnectedRect {
            id: opt

            required property var modelData
            // "" = like all games, "on", "off"
            readonly property string mine: {
                const v = root.game?.env?.[modelData[0]];
                return v === undefined ? "" : v === modelData[2] ? "on" : "off";
            }
            readonly property bool allOn: Games.globalOn(modelData)

            Layout.fillWidth: true
            implicitHeight: optL.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: optL

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: opt.modelData[1]
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: opt.mine ? (opt.mine === "on" ? Tr.tr("On for this game") : Tr.tr("Off for this game")) : opt.allOn ? Tr.tr("On (like all games)") : Tr.tr("Off (like all games)")
                        color: opt.mine ? Colours.palette.m3primary : Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                Repeater {
                    model: [["", Tr.tr("Like all")], ["on", Tr.tr("On")], ["off", Tr.tr("Off")]]

                    TextButton {
                        required property var modelData

                        enabled: root.canChange
                        text: modelData[1]
                        isToggle: true
                        followChecked: true
                        checked: opt.mine === modelData[0]
                        type: TextButton.Tonal
                        onClicked: {
                            const env = {};
                            env[opt.modelData[0]] = modelData[0] === "" ? null : modelData[0] === "on" ? opt.modelData[2] : opt.modelData[3];
                            root.change({
                                env
                            });
                        }
                    }
                }
            }
        }

        SectionHeader {
            visible: !!root.game
            text: "NVIDIA"
        }

        Repeater {
            model: root.game ? Games.nvidiaOptions : []

            OptionRow {}
        }

        SectionHeader {
            visible: !!root.game
            text: "Proton"
        }

        Repeater {
            model: root.game ? Games.protonOptions : []

            OptionRow {}
        }

        // What else its launcher has for it (kept as it is)
        SectionHeader {
            visible: !!root.game && ((root.game.otherEnv ?? []).length > 0 || (root.game.wrappers ?? []).length > 0 || !!root.game.args)
            text: Tr.tr("Also set in %1").arg(Games.launcherNames[root.game?.launcher] ?? "")
        }

        InfoRow {
            visible: !!root.game && (root.game.otherEnv ?? []).length > 0
            icon: "tune"
            label: Tr.tr("Other options")
            value: ""
            subtext: (root.game?.otherEnv ?? []).join(" ")
        }

        InfoRow {
            visible: !!root.game && (root.game.wrappers ?? []).length > 0
            icon: "terminal"
            label: Tr.tr("Runs through")
            value: ""
            subtext: (root.game?.wrappers ?? []).join(" ")
        }

        InfoRow {
            visible: !!root.game?.args
            icon: "input"
            label: Tr.tr("Game arguments")
            value: ""
            subtext: root.game?.args ?? ""
        }

        RowButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: !!root.game?.removable
            disabled: !root.canChange
            icon: "playlist_remove"
            text: Tr.tr("Take it off %1's list").arg(Games.launcherNames[root.game?.launcher] ?? "")
            subtext: Tr.tr("Its files and Wine prefix stay where they are")
            onClicked: {
                Games.remove(root.game.key, root.game.title);
                root.nState.closeSubPage();
            }
        }
    }
}
