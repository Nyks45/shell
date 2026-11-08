pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages

// Windows: their look, desktop mode; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Windows")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [lookPart, desktopPart]
        }

        TabPart {
            id: lookPart

            title: Tr.tr("Look")
            icon: "select_window"
            summary: Tr.tr("Gaps, borders, blur, shadows, animations")

            WindowsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: desktopPart

            title: Tr.tr("Desktop mode")
            icon: "desktop_windows"
            summary: Tr.tr("Floating windows, title bars, snapping")

            DesktopModePage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
