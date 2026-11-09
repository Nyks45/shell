pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Getting apps: one search over the system repositories, the AUR and Flathub,
// and, before searching, the popular apps by category. Install from the
// list; a row opens the app's page.
PageBase {
    id: root

    property string query
    // { repo, aur, flatpak, errors }
    property var results: null
    property bool searching
    property string searchedFor
    // "all", "repo", "aur", "flatpak"
    property string source: "all"
    property var popular: []
    property int category
    property bool showAll

    readonly property var shown: {
        if (!results)
            return [];
        const all = source === "all" ? [...results.repo, ...results.flatpak, ...results.aur] : results[source] ?? [];
        return all;
    }

    function search(): void {
        if (!query.trim()) {
            results = null;
            return;
        }
        searching = true;
        if (searchProc.running)
            return; // the newer words are searched when this one ends
        searchedFor = query.trim();
        searchProc.command = [Packages.helper, "search", searchedFor];
        searchProc.running = true;
    }

    title: Tr.tr("Get apps")

    Component.onCompleted: popularProc.running = true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledTextField {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            placeholderText: Tr.tr("Search apps and packages")
            leadingIcon: "search"
            onTextChanged: {
                root.query = text;
                root.showAll = false;
                searchDelay.restart();
            }
        }

        // Before searching: popular apps by category
        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: !root.query.trim()
            spacing: Tokens.spacing.small

            Repeater {
                model: root.popular

                TextButton {
                    required property var modelData
                    required property int index

                    text: modelData.title
                    isToggle: true
                    followChecked: true
                    checked: root.category === index
                    type: TextButton.Tonal
                    onClicked: root.category = index
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !root.query.trim() && root.popular.length === 0
            text: Tr.tr("Reading…")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.query.trim() ? [] : (root.popular[root.category]?.items ?? [])

            PackageRow {
                required property var modelData

                item: modelData
                nState: root.nState
            }
        }

        // Search results
        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!root.query.trim() && !!root.results
            spacing: Tokens.spacing.small

            Repeater {
                model: [["all", Tr.tr("All")], ["repo", Tr.tr("System")], ["flatpak", "Flathub"], ["aur", "AUR"]]

                TextButton {
                    required property var modelData

                    readonly property int count: !root.results ? 0 : modelData[0] === "all" ? root.results.repo.length + root.results.aur.length + root.results.flatpak.length : (root.results[modelData[0]]?.length ?? 0)

                    text: `${modelData[1]} (${count})`
                    isToggle: true
                    followChecked: true
                    checked: root.source === modelData[0]
                    type: TextButton.Tonal
                    onClicked: {
                        root.source = modelData[0];
                        root.showAll = false;
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !!root.query.trim() && (root.searching || root.shown.length === 0)
            text: root.searching ? Tr.tr("Searching…") : Tr.tr("Nothing found")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !!root.results && Object.keys(root.results.errors ?? {}).length > 0
            text: Tr.tr("Couldn't search %1 (offline?)").arg(Object.keys(root.results?.errors ?? {}).map(k => k === "aur" ? "the AUR" : k === "flatpak" ? "Flathub" : Tr.tr("the system repositories")).join(", "))
            color: Colours.palette.m3error
            font: Tokens.font.label.small
        }

        Repeater {
            model: root.showAll ? root.shown : root.shown.slice(0, 25)

            PackageRow {
                required property var modelData

                item: modelData
                nState: root.nState
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: !root.showAll && root.shown.length > 25
            icon: "expand_more"
            text: Tr.tr("Show all %1").arg(root.shown.length)
            onClicked: root.showAll = true
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.small
            visible: root.source === "aur" && root.shown.length > 0
            text: Tr.tr("AUR packages are recipes shared by the community, built on this computer; check one you don't know before installing it.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Timer {
            id: searchDelay

            interval: 450
            onTriggered: root.search()
        }

        Process {
            id: searchProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.results = JSON.parse(text);
                    } catch (e) {
                        root.results = {
                            repo: [],
                            aur: [],
                            flatpak: [],
                            errors: {}
                        };
                    }
                    root.searching = false;
                    if (root.query.trim() && root.query.trim() !== root.searchedFor)
                        root.search();
                }
            }
        }

        Process {
            id: popularProc

            command: [Packages.helper, "popular"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.popular = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }

        // Installed or removed something: the marks in the lists follow
        Connections {
            target: Packages

            function onChanged(): void {
                popularProc.running = true;
                if (root.query.trim())
                    root.search();
            }
        }
    }
}
