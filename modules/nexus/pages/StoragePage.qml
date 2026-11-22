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
import qs.modules.nexus
import qs.modules.nexus.common
import qs.modules.nexus.pages.disks

// Drives & Storage overview: live / and /home capacity bars, category breakdown,
// shortcut to Clean up, and expandable per-drive partition cards.
PageBase {
    id: root

    property var categoryData: null
    readonly property var categoryItems: {
        const d = categoryData;
        if (!d)
            return [];
        const list = [
            {
                id: "apps",
                label: Tr.tr("Apps & packages"),
                bytes: Math.max(0, d.apps ?? 0),
                color: Colours.palette.m3primary,
                count: 0
            },
            {
                id: "games",
                label: Tr.tr("Games"),
                bytes: Math.max(0, d.games ?? 0),
                color: Colours.palette.m3secondary,
                count: 0
            },
            {
                id: "caches",
                label: Tr.tr("Caches"),
                bytes: Math.max(0, d.caches ?? 0),
                color: Colours.palette.m3tertiary,
                count: 0
            },
            {
                id: "logs",
                label: Tr.tr("Logs & dumps"),
                bytes: Math.max(0, d.logs ?? 0),
                color: Colours.palette.m3error,
                count: 0
            },
            {
                id: "snapshots",
                label: Tr.tr("Snapshots"),
                bytes: Math.max(0, d.snapshots ?? 0),
                color: Colours.palette.m3outline,
                count: d.snapshotCount ?? 0
            }
        ];
        return list.filter(x => x.bytes > 0 || x.count > 0);
    }
    readonly property real categoryTotal: categoryItems.reduce((sum, x) => sum + x.bytes, 0)

    readonly property var overviewMounts: {
        const targets = ["/", "/home"];
        const out = [];
        const seen = {};
        for (const target of targets) {
            for (const d of Disks.drives ?? []) {
                const items = [...(d.partitions ?? []), ...(d.whole ? [d.whole] : [])];
                for (const p of items) {
                    const fs = p.crypto?.inner ?? p.fs;
                    const mounts = fs?.mounts ?? [];
                    if (!mounts.includes(target))
                        continue;
                    if (!((fs?.size ?? 0) > 0) || seen[target])
                        continue;
                    seen[target] = true;
                    out.push({
                        mount: target,
                        title: target === "/" ? Tr.tr("System (/)") : Tr.tr("Home (/home)"),
                        icon: target === "/" ? "computer" : "home",
                        used: Math.max(0, fs.used ?? 0),
                        total: fs.size
                    });
                }
            }
        }
        return out;
    }

    title: Tr.tr("Storage")

    Component.onCompleted: {
        Disks.open();
        overviewProc.running = true;
    }
    Component.onDestruction: Disks.close()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Process {
            id: overviewProc

            command: [`${Paths.libdir}/caelestia-system`, "storage-overview"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.categoryData = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Overview")
        }

        Repeater {
            model: root.overviewMounts

            ConnectedRect {
                id: ov

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: ovCol.implicitHeight + Tokens.padding.medium * 2

                ColumnLayout {
                    id: ovCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: ov.modelData.icon
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: ov.modelData.title
                            font: Tokens.font.body.small
                        }

                        StyledText {
                            text: Tr.tr("%1 used of %2").arg(Disks.human(ov.modelData.used)).arg(Disks.human(ov.modelData.total))
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        value: ov.modelData.total > 0 ? Math.min(1, ov.modelData.used / ov.modelData.total) : 0
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("%1 free (%2% used)").arg(Disks.human(Math.max(0, ov.modelData.total - ov.modelData.used))).arg(Math.round(ov.modelData.total > 0 ? ov.modelData.used / ov.modelData.total * 100 : 0))
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }
            }
        }

        ConnectedRect {
            visible: root.categoryTotal > 0 || root.categoryItems.length > 0
            Layout.fillWidth: true
            implicitHeight: catCol.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: catCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "donut_small"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Usage by category")
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        visible: root.categoryTotal > 0
                        text: Disks.human(root.categoryTotal)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }

                StyledRect {
                    visible: root.categoryTotal > 0
                    Layout.fillWidth: true
                    implicitHeight: 10
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHighest
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 2

                        Repeater {
                            model: root.categoryItems.filter(x => x.bytes > 0)

                            StyledRect {
                                required property var modelData

                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                Layout.preferredWidth: Math.max(1, Math.round(modelData.bytes / 1048576))
                                Layout.minimumWidth: 4
                                radius: 2
                                color: modelData.color
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    Repeater {
                        model: root.categoryItems

                        RowLayout {
                            required property var modelData

                            spacing: Tokens.spacing.extraSmall

                            Rectangle {
                                implicitWidth: 8
                                implicitHeight: 8
                                radius: 4
                                color: modelData.color
                            }

                            StyledText {
                                text: modelData.bytes > 0 ? `${modelData.label}: ${Disks.human(modelData.bytes)}` : Tr.trN("%1 (%n)", "%1 (%n)", modelData.count).arg(modelData.label)
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }
        }

        RowButton {
            icon: "cleaning_services"
            text: Tr.tr("Clean up space")
            subtext: Tr.tr("Inspect Home folder sizes and clear Trash, caches, unused packages, Flatpaks and crash dumps")
            trailingIcon: "chevron_right"
            onClicked: root.nState.goTo({
                page: PageRegistry.find("storage"),
                tab: "cleanup",
                path: []
            })
        }

        SectionHeader {
            text: Tr.tr("Drives")
        }

        // Each drive, unfolding to its partitions, free space, health and actions
        DriveCards {
            Layout.fillWidth: true
            nState: root.nState
            flickable: root.flickable
        }
    }
}
