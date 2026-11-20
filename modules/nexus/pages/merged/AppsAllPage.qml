pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps

// Apps: what's installed, getting apps (repositories, AUR, Flatpak),
// default apps, apps that start at login; one at a time (tabs).
// Each tab's key is its former page id.
PageBase {
    id: root

    title: Tr.tr("Apps")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [installedPart, getPart, defaultsPart, startupPart]
        }

        TabPart {
            id: installedPart

            key: "installed"
            title: Tr.tr("Installed")

            InstalledPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: getPart

            key: "getapps"
            title: Tr.tr("Get apps")

            GetAppsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: defaultsPart

            key: "defaultapps"
            title: Tr.tr("Default apps")

            AppsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: startupPart

            key: "startup"
            title: Tr.tr("Startup")

            StartupPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
