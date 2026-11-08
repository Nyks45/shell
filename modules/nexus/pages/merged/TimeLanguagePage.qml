pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages

// Time & language: time zone and clock, language and units; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Time & language")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [timePart, languagePart]
        }

        TabPart {
            id: timePart

            title: Tr.tr("Date & time")
            icon: "schedule"
            summary: Tr.tr("Time zone, automatic time, clock format")

            DateTimePage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: languagePart

            title: Tr.tr("Language & region")
            icon: "translate"
            summary: Tr.tr("Language, weather location, units")

            LanguageAndRegion {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
