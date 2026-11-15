pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    // Its settings as they will be (changes made while its launcher is open wait for it to close)
    readonly property var shown: Games.withPending(game)
    readonly property bool blocked: !!game && Games.blocked(game.launcher)
    readonly property bool waiting: !!game && Games.hasPending(game.key)
    readonly property string what: Tr.tr("Change %1's settings").arg(game?.title ?? "")
    readonly property bool busy: Admin.jobs.some(j => j.what === root.what)
    readonly property bool canChange: !!game && !busy
    readonly property bool justSaved: !!game && Games.savedKeys.includes(game.key)
    readonly property bool restarting: !!game && Games.restartAfter.includes(game.launcher)
    readonly property string launcherName: Games.launcherNames[game?.launcher] ?? ""
    readonly property var choices: launcher.choices ?? []

    function change(c: var): void {
        Games.set(game.key, c, what);
    }

    // The game's newest Proton log (caelestia-gaming game-log): { path, size, modified, errors, tail }
    property var log: null

    // One launch's log (its path), else the newest
    function readLog(path): void {
        if (!game)
            return;
        root.logProc.command = [Games.helper, "game-log", game.key, ...(path ? [path] : [])];
        root.logProc.running = true;
    }

    onGameChanged: if (game && log === null)
        readLog()

    readonly property Process logProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.log = JSON.parse(text);
                } catch (e) {
                    root.log = null;
                }
            }
        }
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

        // Saved or waiting: what happened to this game's changes, and "Save now"
        ConnectedRect {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.game && (root.blocked || root.busy || root.waiting || root.justSaved)
            implicitHeight: saveL.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: saveL

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: root.busy || root.restarting ? "sync" : root.waiting ? "schedule" : root.justSaved ? "check_circle" : "info"
                    color: root.waiting || root.busy || root.restarting ? Colours.palette.m3tertiary : root.justSaved ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.busy ? Tr.tr("Saving…") : root.restarting ? Tr.tr("Closing %1 to save…").arg(root.launcherName) : root.waiting ? Tr.tr("Changes not saved yet") : root.justSaved ? Tr.tr("Saved") : Tr.tr("%1 is open").arg(root.launcherName)
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.restarting ? Tr.tr("It starts again once the changes are saved") : root.waiting ? Tr.tr("Saved as soon as %1 is closed: it writes its old settings back when it quits").arg(root.launcherName) : root.justSaved ? Tr.tr("The changes are in %1's settings").arg(root.launcherName) : Tr.tr("Changes made now are saved as soon as it's closed")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.WordWrap
                    }
                }

                TextButton {
                    visible: root.waiting && root.blocked && root.game?.launcher === "steam" && !root.restarting
                    text: Tr.tr("Save now")
                    type: TextButton.Filled
                    onClicked: Games.saveNow("steam")
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.waiting && root.blocked && root.game?.launcher === "steam" && !root.restarting
            // TRANSLATORS: explains the Save now button
            text: Tr.tr("Save now closes Steam (and a game running from it), saves, and starts Steam again.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
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
                    checked: (root.shown?.proton ?? "") === modelData[0]
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
            checked: !!root.shown?.mangohud
            onToggled: root.change({
                mangohud: checked
            })
        }

        ToggleRow {
            visible: !!root.game && root.game.perf !== null && root.game.perf !== undefined
            enabled: root.canChange
            text: Tr.tr("Performance mode")
            subtext: Tr.tr("The performance power profile and the scheduler's Gaming mode while it runs (game-performance)")
            checked: !!root.shown?.perf
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
                const v = root.shown?.env?.[modelData[0]];
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

        // Logs: Proton's log for this game (Proton > Proton logs above turns it on), its error
        // lines shown here, the whole file opened in the editor
        SectionHeader {
            visible: !!root.game && root.game.proton !== null && root.game.proton !== undefined
            text: Tr.tr("Logs")
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: !!root.game && root.log !== null
            implicitHeight: logL.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: logL

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.log?.path ? Tr.tr("Launch of %1 (%2 kept)").arg(new Date(((root.log.runs ?? []).find(r => r.path === root.log.path)?.started ?? root.log.modified ?? 0) * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)).arg((root.log.runs ?? []).length) : Tr.tr("No log yet")
                            font: Tokens.font.body.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.log?.path ? `${Paths.shortenHome(root.log.path)} · ${root.size(root.log.size ?? 0) || "0 MB"}` : Tr.tr("Set Proton > Proton logs to On above, start the game, then come back")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideMiddle
                        }
                    }

                    TextButton {
                        visible: !!root.log?.path
                        text: Tr.tr("Open")
                        type: TextButton.Tonal
                        onClicked: Quickshell.execDetached(["xdg-open", root.log.path])
                    }

                    TextButton {
                        visible: !!root.log?.path
                        text: Tr.tr("Delete all")
                        type: TextButton.Text
                        onClicked: Admin.exec([Games.helper, "game-log", root.game.key, "delete"], Tr.tr("Delete %1's logs").arg(root.game.title), () => root.readLog())
                        // (all of this game's kept launches)
                    }

                    TextButton {
                        text: Tr.tr("Refresh")
                        type: TextButton.Text
                        onClicked: root.readLog()
                    }
                }

                // Each launch keeps its own log (caelestia-gamelogs.path files them)
                Flow {
                    Layout.fillWidth: true
                    visible: (root.log?.runs ?? []).length > 1
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.log?.runs ?? []

                        TextButton {
                            required property var modelData

                            text: new Date(modelData.started * 1000).toLocaleString(Qt.locale(), "d MMM HH:mm")
                            isToggle: true
                            followChecked: true
                            checked: modelData.path === root.log?.path
                            type: TextButton.Tonal
                            onClicked: root.readLog(modelData.path)
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !!root.log?.path
                    text: (root.log?.errors ?? []).length > 0 ? Tr.tr("Errors and warnings (the end of the log):") : Tr.tr("No errors found at the end of the log. Its last lines:")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledRect {
                    Layout.fillWidth: true
                    visible: !!root.log?.path
                    implicitHeight: Math.min(logText.implicitHeight + Tokens.padding.medium * 2, 320)
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3surfaceContainerLowest
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        contentHeight: logText.implicitHeight
                        contentWidth: width
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: logText

                            width: parent.width
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            text: ((root.log?.errors ?? []).length > 0 ? root.log.errors : root.log?.tail ?? []).join("\n")
                            color: Colours.palette.m3onSurface
                            selectionColor: Colours.palette.m3primary
                            font.family: "monospace"
                            font.pixelSize: 11
                        }
                    }
                }
            }
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
