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

    function clearSearch(): void {
        searchField.text = "";
    }

    spacing: Tokens.spacing.medium

    // The window's title, plus back / forward history controls
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

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "arrow_back"
            type: IconButton.Text
            stateLayer.disabled: !root.nState.canGoBack
            opacity: root.nState.canGoBack ? 1 : 0.35
            onClicked: root.nState.back()
        }

        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "arrow_forward"
            type: IconButton.Text
            stateLayer.disabled: !root.nState.canGoForward
            opacity: root.nState.canGoForward ? 1 : 0.35
            onClicked: root.nState.forward()
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
        onAccepted: (resultsLoader.item as SearchResults)?.openFirst()
        Keys.onEscapePressed: text = ""
        onTextChanged: {
            root.nState.searchText = text;
            root.nState.searchOpen = text.trim().length > 0;
        }

        Connections {
            function onSearchOpenChanged(): void {
                if (!root.nState.searchOpen) {
                    if (searchField.text.length > 0)
                        searchField.text = "";
                    if (searchField.activeFocus)
                        searchField.focus = false;
                }
            }

            target: root.nState
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NavLocations {
            anchors.fill: parent
            anchors.topMargin: -topMargin
            anchors.bottomMargin: -bottomMargin
            visible: !root.nState.searchOpen
            enabled: visible
            nState: root.nState
        }

        Loader {
            id: resultsLoader

            anchors.fill: parent
            z: 1
            active: root.nState.searchOpen
            visible: active
            enabled: active

            sourceComponent: SearchResults {
                nState: root.nState
            }
        }
    }
}
