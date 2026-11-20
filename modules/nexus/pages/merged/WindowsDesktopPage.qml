pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages

// Windows: their look, desktop mode, title bars and app rules; one at a time (tabs).
// The parts are embedded pages (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Windows")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [lookPart, desktopPart, titleBarsPart, appRulesPart]
        }

        TabPart {
            id: lookPart

            key: "windows-look"
            title: Tr.tr("Look")
            icon: "select_window"
            summary: Tr.tr("Gaps, borders, shadows, animations")

            WindowsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: desktopPart

            key: "desktopmode"
            title: Tr.tr("Desktop mode")
            icon: "desktop_windows"
            summary: Tr.tr("Floating windows, snapping, hot corners")

            DesktopModePage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: titleBarsPart

            key: "titlebars"
            title: Tr.tr("Title bars")
            icon: "view_agenda"
            summary: Tr.tr("Fonts, blur, buttons, hover and click actions")

            TitleBarsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: appRulesPart

            key: "apprules"
            title: Tr.tr("App rules")
            icon: "rule"
            summary: Tr.tr("Per-app floating, centring, workspaces, opacity")

            AppRulesPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
