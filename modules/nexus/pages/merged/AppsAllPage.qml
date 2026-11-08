pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps

// Apps: default apps and favourites, apps that start at login, updates; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Apps")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [appsPart, startupPart, updatesPart]
        }

        TabPart {
            id: appsPart

            title: Tr.tr("Apps")
            icon: "apps"
            summary: Tr.tr("Default apps, favourites, all installed apps")

            AppsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: startupPart

            title: Tr.tr("Startup")
            icon: "rocket_launch"
            summary: Tr.tr("Apps that start when you log in")

            StartupPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: updatesPart

            title: Tr.tr("Updates")
            icon: "system_update"
            summary: Tr.tr("System and app updates")

            UpdatesPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
