pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.system

// System: services and scheduled tasks, logs, Hyprland plugins; one at a
// time (each is a long list).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("System")

    // A service's page opened its full log: show the Logs part
    function showLogUnit(): void {
        if (root.nState.logUnit)
            tabs.show(logsPart);
    }

    Component.onCompleted: showLogUnit()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            target: root.nState

            function onLogUnitChanged(): void {
                root.showLogUnit();
            }
        }

        PartTabs {
            id: tabs

            parts: [servicesPart, logsPart, pluginsPart]
        }

        TabPart {
            id: servicesPart

            title: Tr.tr("Services")
            icon: "settings_applications"
            summary: Tr.tr("What runs in the background: start, stop, start at boot")

            SystemServicesPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: logsPart

            title: Tr.tr("Logs")
            icon: "receipt_long"
            summary: Tr.tr("System messages, errors, crash reports")

            LogsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: pluginsPart

            title: Tr.tr("Plugins")
            icon: "extension"
            summary: Tr.tr("Hyprland plugins")

            PluginsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
