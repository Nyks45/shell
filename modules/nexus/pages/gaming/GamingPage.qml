pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

// Gaming: overview, library (with per-game settings), graphics (GPU + global
// game options), Proton compatibility versions, and MangoHud overlay; 5 single-row tabs.
PageBase {
    id: root

    title: Tr.tr("Gaming")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [overviewPart, libraryPart, graphicsPart, compatPart, overlayPart]
        }

        TabPart {
            id: overviewPart

            key: "gamemode"
            title: Tr.tr("Overview")

            GamingOverview {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: libraryPart

            key: "library"
            title: Tr.tr("Library")

            LibraryPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: graphicsPart

            key: "gpu"
            altKeys: ["games"]
            title: Tr.tr("Graphics")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                GpuPage {
                    embedded: true
                    Layout.fillWidth: true
                    nState: root.nState
                    hostFlickable: root.flickable
                }

                GameOptionsPage {
                    embedded: true
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.largeIncreased
                    nState: root.nState
                    hostFlickable: root.flickable
                }
            }
        }

        TabPart {
            id: compatPart

            key: "proton"
            title: Tr.tr("Compatibility")

            ProtonPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: overlayPart

            key: "overlay"
            title: Tr.tr("Overlay")

            OverlayPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
