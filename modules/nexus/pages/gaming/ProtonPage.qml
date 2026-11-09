pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Proton and Wine versions for every launcher at once (ProtonPlus's job):
// what's installed (sizes, remove), updating the "… Latest" copies launchers
// point at (one stable name: their settings never change), installing other
// versions (checked against the release's checksum), the launchers' defaults.
PageBase {
    id: root

    property var tools: null
    property string source: "proton-ge"
    property var releases: null
    property bool loadingReleases
    property string target: "steam"
    readonly property string helper: `${Paths.libdir}/caelestia-gaming`
    readonly property var sourceNames: [["proton-ge", "Proton-GE"], ["proton-cachyos", "Proton-CachyOS"], ["proton-em", "Proton-EM"], ["dwproton", "DW-Proton"], ["wine-tkg", "Wine TkG"]]
    readonly property var targetNames: [["steam", "Steam (and Faugus)"], ["lutris", "Lutris"], ["heroic", "Heroic"]]
    readonly property var mine: (tools?.tools ?? []).filter(t => !t.system)
    // An installed "Latest" copy for the chosen source, and the newest release
    readonly property var latestCopy: mine.find(t => t.target === root.target && t.name === root.releases?.latest) ?? null
    readonly property var newest: releases?.releases?.[0] ?? null

    function load(): void {
        toolsProc.running = true;
    }

    function loadReleases(): void {
        releases = null;
        loadingReleases = true;
        relProc.command = [helper, "releases", source];
        relProc.running = true;
    }

    function size(b: real): string {
        return b > 1073741824 ? `${(b / 1073741824).toFixed(1)} GB` : `${Math.round(b / 1048576)} MB`;
    }

    function install(tag: string, latest: bool): void {
        Admin.exec([helper, "install", source, tag, target, ...(latest ? ["--latest"] : [])], Tr.tr("Install %1").arg(latest ? releases.latest : tag), () => root.load());
    }

    function busyText(what: string): string {
        const lines = Admin.outputOf(what).trim().split("\n");
        return lines[lines.length - 1] ?? "";
    }

    title: Tr.tr("Proton versions")

    Component.onCompleted: {
        load();
        loadReleases();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Installed, per launcher
        Repeater {
            model: root.tools ? root.targetNames.filter(t => (root.tools.tools ?? []).some(x => x.target === t[0])) : []

            ColumnLayout {
                id: tg

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: tg.index === 0
                    text: tg.modelData[1]
                }

                Repeater {
                    model: (root.tools?.tools ?? []).filter(t => t.target === tg.modelData[0])

                    ConnectedRect {
                        id: row

                        required property var modelData

                        readonly property bool isDefault: tg.modelData[0] === "steam" && root.tools.steamDefault === modelData.name
                        readonly property bool duplicate: !modelData.latest && !modelData.system && (root.tools.tools ?? []).some(t => t.latest && t.target === modelData.target && t.size === modelData.size)
                        readonly property string removeWhat: Tr.tr("Remove %1").arg(modelData.name)

                        Layout.fillWidth: true
                        implicitHeight: rowL.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: rowL

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: row.isDefault ? "star" : row.modelData.latest ? "autorenew" : "deployed_code"
                                color: row.isDefault ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: [row.modelData.system ? Tr.tr("system package") : root.size(row.modelData.size), row.isDefault ? Tr.tr("Steam's default") : "", row.modelData.latest ? Tr.tr("kept up to date here") : "", row.duplicate ? Tr.tr("same as the Latest copy: removable") : ""].filter(s => s).join(" · ")
                                    color: row.duplicate ? Colours.palette.m3primary : Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                }
                            }

                            TextButton {
                                visible: tg.modelData[0] === "steam" && !row.isDefault && !root.tools.steamRunning
                                text: Tr.tr("Make default")
                                type: TextButton.Text
                                onClicked: Admin.exec([root.helper, "set-default", "steam", row.modelData.name], Tr.tr("Make %1 Steam's default").arg(row.modelData.name), () => root.load())
                            }

                            TextButton {
                                visible: !row.modelData.system
                                enabled: !Admin.jobs.some(j => j.what === row.removeWhat)
                                text: Tr.tr("Remove")
                                type: TextButton.Tonal
                                onClicked: Admin.exec([root.helper, "remove", row.modelData.target, row.modelData.dir], row.removeWhat, () => root.load())
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.tools?.steamRunning
            text: Tr.tr("Steam is open: its default can be changed once it's closed (it rewrites its settings when it quits).")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        // Install / update
        SectionHeader {
            text: Tr.tr("Get versions")
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            Repeater {
                model: root.sourceNames

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.source === modelData[0]
                    type: TextButton.Tonal
                    onClicked: {
                        root.source = modelData[0];
                        if (modelData[0] === "wine-tkg")
                            root.target = "lutris";
                        root.loadReleases();
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            StyledText {
                text: Tr.tr("Into:")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                topPadding: Tokens.padding.small
            }

            Repeater {
                model: root.targetNames.filter(t => root.tools?.accepts?.[t[0]]?.includes(root.source))

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.target === modelData[0]
                    type: TextButton.Tonal
                    onClicked: root.target = modelData[0]
                }
            }
        }

        // The Latest copy behind the newest release: update it
        RowButton {
            readonly property string what: Tr.tr("Install %1").arg(root.releases?.latest ?? "")
            readonly property bool working: Admin.jobs.some(j => j.what === what)

            Layout.fillWidth: true
            visible: !!root.releases?.latest && !!root.newest
            disabled: working
            icon: working ? "downloading" : "autorenew"
            text: root.latestCopy ? Tr.tr("Update %1 to %2").arg(root.releases?.latest ?? "").arg(root.newest?.tag ?? "") : Tr.tr("Add %1 (%2)").arg(root.releases?.latest ?? "").arg(root.newest?.tag ?? "")
            subtext: working ? root.busyText(what) : Tr.tr("One name launchers keep pointing at; updating replaces it with the newest version (%1)").arg(root.size(root.newest?.size ?? 0))
            onClicked: root.install(root.newest.tag, true)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.loadingReleases || (!!root.releases && root.releases.releases.length === 0)
            text: root.loadingReleases ? Tr.tr("Reading the releases…") : Tr.tr("No releases found")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.releases?.releases ?? []

            RowButton {
                id: rel

                required property var modelData

                readonly property string what: Tr.tr("Install %1").arg(modelData.tag)
                readonly property bool working: Admin.jobs.some(j => j.what === what)
                readonly property bool have: root.mine.some(t => t.target === root.target && (t.dir.includes(modelData.tag) || t.name.includes(modelData.tag)))

                Layout.fillWidth: true
                disabled: working || have
                icon: have ? "check" : working ? "downloading" : "download"
                text: modelData.tag
                subtext: working ? root.busyText(what) : have ? Tr.tr("Installed") : `${modelData.date} · ${root.size(modelData.size)}`
                onClicked: root.install(modelData.tag, false)
            }
        }

        Process {
            id: toolsProc

            command: [root.helper, "tools"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.tools = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }

        Process {
            id: relProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.releases = JSON.parse(text);
                    } catch (e) {
                        root.releases = {
                            releases: []
                        };
                    }
                    root.loadingReleases = false;
                }
            }
        }
    }
}
