pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common
import qs.modules.nexus.pages.disks

// Drives & Storage overview: live / and /home capacity bars, shortcut to Clean up,
// and expandable per-drive partition cards.
PageBase {
    id: root

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

    Component.onCompleted: Disks.open()
    Component.onDestruction: Disks.close()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

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
