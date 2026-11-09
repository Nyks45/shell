pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps

// Apps: what's installed, getting apps (repositories, AUR, Flathub), updates,
// default apps, apps that start at login; one at a time (tabs). The parts are
// pages of their own, embedded (PageBase.embedded); each tab's key is its
// former page id (opening Settings at "updates" shows that tab).
PageBase {
    id: root

    title: Tr.tr("Apps")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [installedPart, getPart, updatesPart, defaultsPart, startupPart]
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
            id: updatesPart

            key: "updates"
            title: Tr.tr("Updates")

            UpdatesPage {
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
