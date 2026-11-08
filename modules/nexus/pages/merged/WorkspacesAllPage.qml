pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages

// Workspaces & shortcuts: focus and workspaces, keyboard shortcuts, screenshots; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Workspaces & shortcuts")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [workspacesPart, shortcutsPart, screenshotsPart]
        }

        TabPart {
            id: workspacesPart

            title: Tr.tr("Workspaces")
            icon: "view_carousel"
            summary: Tr.tr("Focus, workspaces, the scrolling layout")

            MultitaskingPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: shortcutsPart

            title: Tr.tr("Shortcuts")
            icon: "keyboard_command_key"
            summary: Tr.tr("Keyboard shortcuts")

            ShortcutsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: screenshotsPart

            title: Tr.tr("Screenshots")
            icon: "screenshot_region"
            summary: Tr.tr("Screenshots and screen recording")

            ScreenshotsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
