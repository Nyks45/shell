import "navpane"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.medium

    // The window's title, like DankMaterialShell's settings
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.small
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: "settings"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.medium
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Settings")
            font: Tokens.font.title.medium
        }
    }

    // Who's signed in: a click opens the account page
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: profileRow.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        StateLayer {
            onClicked: root.nState.currentPageIdx = PageRegistry.find("account")
        }

        RowLayout {
            id: profileRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            ClipRect {
                implicitWidth: 44
                implicitHeight: 44
                radius: 22
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: "person"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.medium
                }

                Image {
                    id: face

                    anchors.fill: parent
                    source: Paths.faceSource ? `file://${Paths.faceSource}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 88
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: SysInfo.user
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: SysInfo.hostname
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    SearchBar {
        id: searchField

        z: 1
        Layout.fillWidth: true

        placeholderText: Tr.tr("Search settings")
        font: Tokens.font.body.medium

        bg.color: Colours.tPalette.m3surfaceContainerLowest
        bg.border.color: Colours.palette.m3outlineVariant
        searchIcon.fontStyle: Tokens.font.icon.medium
        searchIcon.anchors.leftMargin: Tokens.padding.largeIncreased
        clearIcon.font: Tokens.font.icon.medium
        clearIcon.padding: Tokens.padding.extraSmall

        Behavior on bg.border.color {
            CAnim {}
        }

        // Enter opens the first result, Escape clears the search
        onAccepted: results.openFirst()
        Keys.onEscapePressed: text = ""

        Binding {
            target: root.nState
            property: "searchOpen"
            value: searchField.text.trim().length > 0
        }

        Binding {
            target: root.nState
            property: "searchText"
            value: searchField.text
        }
    }

    NavLocations {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        visible: !root.nState.searchOpen
        nState: root.nState
    }

    SearchResults {
        id: results

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.nState.searchOpen
        nState: root.nState
    }
}
