pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.disks

// Storage: drives, clean up, snapshots; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Storage")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [drivesPart, snapshotsPart]
        }

        TabPart {
            id: drivesPart

            title: Tr.tr("Drives")
            icon: "hard_drive"
            summary: Tr.tr("Drives and partitions, home folder, clean up")

            StoragePage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: snapshotsPart

            title: Tr.tr("Snapshots")
            icon: "history"
            summary: Tr.tr("System snapshots to go back to")

            BackupsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
