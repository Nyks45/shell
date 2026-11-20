pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.system

// Advanced: services and scheduled tasks, logs, kernels, CPU scheduler & shell
// monitoring performance, and Hyprland plugins; one at a time (tabs).
PageBase {
    id: root

    title: Tr.tr("Advanced")

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

            parts: [servicesPart, logsPart, kernelsPart, perfPart, pluginsPart]
        }

        TabPart {
            id: servicesPart

            key: "systemd"
            altKeys: ["services"]
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

            key: "logs"
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
            id: kernelsPart

            key: "kernels"
            title: Tr.tr("Kernels")

            KernelsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: perfPart

            key: "scheduler"
            altKeys: ["performance"]
            title: Tr.tr("Performance")

            PerformancePage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: pluginsPart

            key: "plugins"
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
