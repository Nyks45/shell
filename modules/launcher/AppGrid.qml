pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.modules.launcher.services

// The centred launcher's apps (the "grid" style): icons with their names, the search's results;
// the current one is highlighted (arrows move it, Enter starts it)
GridView {
    id: root

    required property string query
    required property ScreenState screenState
    property int columns: 6
    // How far the launcher is open: the icons come in row by row as it opens (a cascade)
    property real open: 1

    function launchCurrent(): void {
        if (currentItem)
            launch((currentItem as Cell).modelData);
    }

    function launch(entry: var): void {
        Apps.launch(entry);
        screenState.launcher = false;
    }

    model: ScriptModel {
        values: Apps.search(root.query)
        onValuesChanged: root.currentIndex = 0
    }

    clip: true
    cellWidth: width / columns
    cellHeight: 96
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationWraps: false
    highlightFollowsCurrentItem: true
    highlightMoveDuration: 120

    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
    }

    delegate: Cell {}

    component Cell: Item {
        id: cell

        required property var modelData
        required property int index

        // (rows further down a little later; the first screenful only)
        readonly property real shown: Math.min(1, Math.max(0, (root.open - 0.25 - Math.floor(Math.min(index, 24) / root.columns) * 0.08) / 0.4))

        width: root.cellWidth
        height: root.cellHeight
        opacity: shown
        transform: Translate {
            y: (1 - cell.shown) * 14
        }

        StateLayer {
            anchors.fill: parent
            anchors.margins: 2
            radius: Tokens.rounding.large
            onClicked: root.launch(cell.modelData)
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - Tokens.padding.small * 2
            spacing: Tokens.spacing.small

            ThemedIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 48
                asynchronous: true
                source: Quickshell.iconPath(cell.modelData?.icon, "image-missing")
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: cell.modelData?.name ?? ""
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }
        }
    }
}
