import "navpane"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    SearchBar {
        id: searchField

        z: 1
        Layout.fillWidth: true

        placeholderText: Tr.tr("Search settings")
        font: Tokens.font.body.large

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
