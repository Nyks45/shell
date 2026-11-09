pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

// Gaming: the overview (game mode, tearing…), the games of every launcher
// (each with its own settings: GamePage), the graphics card, options for
// every game, Proton versions, the overlay and the CPU scheduler; one at a
// time. The parts are pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Gaming")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [overviewPart, libraryPart, gpuPart, gamesPart, protonPart, overlayPart, schedulerPart]
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
            id: gpuPart

            key: "gpu"
            title: Tr.tr("Graphics card")

            GpuPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: gamesPart

            key: "games"
            title: Tr.tr("Game options")

            GameOptionsPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: protonPart

            key: "proton"
            title: Tr.tr("Proton versions")

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

        TabPart {
            id: schedulerPart

            key: "scheduler"
            title: Tr.tr("Scheduler")

            SchedulerPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
