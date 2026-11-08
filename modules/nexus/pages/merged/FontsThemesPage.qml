pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages

// Fonts & themes: fonts, icon and app themes; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Fonts & themes")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [fontsPart, themesPart]
        }

        TabPart {
            id: fontsPart

            title: Tr.tr("Fonts")
            icon: "text_fields"
            summary: Tr.tr("Shell and app fonts, sizes, smoothing")

            FontsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: themesPart

            title: Tr.tr("Themes")
            icon: "palette"
            summary: Tr.tr("Icon theme, app style, cursors")

            AppAppearancePage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
