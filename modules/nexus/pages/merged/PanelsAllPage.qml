pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages

// Panels: the shell's panels, the services behind them; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [panelsPart, servicesPart]
        }

        TabPart {
            id: panelsPart

            title: Tr.tr("Panels")
            icon: "dock_to_bottom"
            summary: Tr.tr("Taskbar, dashboard, launcher, sidebar, lock screen")

            PanelsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: servicesPart

            title: Tr.tr("Shell services")
            icon: "tune"
            summary: Tr.tr("Poll intervals, lyrics, media players")

            ServicesPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
