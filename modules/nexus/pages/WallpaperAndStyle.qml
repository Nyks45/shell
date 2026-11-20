pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.wallandstyle

// Wallpaper & style: background, colours, effects (transparency & blur),
// desktop (icons, widgets, visualiser), and lock screen; one at a time (tabs).
PageBase {
    id: root

    title: Tr.tr("Wallpaper & style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            id: tabs

            parts: [backgroundPart, coloursPart, effectsPart, desktopPart, lockPart]
        }

        TabPart {
            id: backgroundPart

            key: "background"
            altKeys: ["style"]
            title: Tr.tr("Background")

            BackgroundTab {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
                onOpenColours: tabs.show(coloursPart)
            }
        }

        TabPart {
            id: coloursPart

            key: "colours"
            title: Tr.tr("Colours")

            ColourSelect {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: effectsPart

            key: "effects"
            title: Tr.tr("Effects")

            EffectsTab {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: desktopPart

            key: "desktop"
            title: Tr.tr("Desktop")

            DesktopTab {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: lockPart

            key: "lockscreen"
            title: Tr.tr("Lock screen")

            LockPanel {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
