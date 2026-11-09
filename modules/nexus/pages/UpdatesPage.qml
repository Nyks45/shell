pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.modules.nexus.common

// Updates: system packages (pacman), the AUR (paru) and Flatpak apps, each
// one chosen or not; packages kept at their version; configuration files an
// update brought (.pacnew); Arch news; automatic checks and notifications.
// The work is in the Packages service (also the background checks).
PageBase {
    id: root

    // Unticked updates (key "source:name"): left out this time
    property var skipped: ({})
    property var news: []
    property var pacnew: []
    // The .pacnew being looked at and its diff
    property var pacnewOpen: null
    property string pacnewDiff
    property bool showAllNews

    readonly property var all: [...Packages.repo.map(u => Object.assign({
                source: "repo"
            }, u)), ...Packages.aur.map(u => Object.assign({
                source: "aur"
            }, u)), ...Packages.flatpak.map(u => Object.assign({
                source: "flatpak"
            }, u))]
    readonly property list<MenuItem> checkItems: [
        MenuItem {
            text: Tr.tr("Never")
            value: 0
        },
        MenuItem {
            text: Tr.tr("Every hour")
            value: 1
        },
        MenuItem {
            text: Tr.tr("Every 3 hours")
            value: 3
        },
        MenuItem {
            text: Tr.tr("Every 6 hours")
            value: 6
        },
        MenuItem {
            text: Tr.tr("Every 12 hours")
            value: 12
        },
        MenuItem {
            text: Tr.tr("Once a day")
            value: 24
        }
    ]
    readonly property int chosen: all.filter(u => !skipped[key(u)]).length

    function key(u: var): string {
        return `${u.source}:${u.appId || u.name}`;
    }

    function toggle(u: var, on: bool): void {
        const s = Object.assign({}, skipped);
        if (on)
            delete s[key(u)];
        else
            s[key(u)] = true;
        skipped = s;
    }

    function setAll(on: bool): void {
        const s = {};
        if (!on)
            for (const u of all)
                s[key(u)] = true;
        skipped = s;
    }

    function updateChosen(): void {
        const skipRepo = Packages.repo.filter(u => skipped[`repo:${u.name}`]).map(u => u.name);
        const aur = Packages.aur.filter(u => !skipped[`aur:${u.name}`]).map(u => u.name);
        const flat = Packages.flatpak.filter(u => !skipped[`flatpak:${u.appId}`]).map(u => u.appId);
        Packages.update(skipRepo, aur, flat, () => root.skipped = {});
    }

    function loadExtras(): void {
        newsProc.running = true;
        pacnewProc.running = true;
    }

    title: Tr.tr("Updates")

    Component.onCompleted: {
        const last = Packages.checkedAt.getTime();
        if (!Packages.checking && (isNaN(last) || last < Date.now() - 10 * 60 * 1000))
            Packages.check(true);
        loadExtras();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // A restart finishes the last update
        InfoRow {
            visible: Packages.restart.length > 0
            icon: "restart_alt"
            iconColour: Colours.palette.m3primary
            label: Tr.tr("Restart to finish updating")
            subtext: Packages.restart.includes("kernel") ? Tr.tr("A new kernel is installed; the running one has no drivers to load any more.") : Tr.tr("The graphics driver was updated; until a restart the old one keeps running.")
        }

        InfoRow {
            icon: Packages.checking ? "sync" : Packages.total > 0 ? "system_update" : "check_circle"
            label: Packages.checking ? Tr.tr("Checking for updates…") : Packages.total > 0 ? Tr.tr("%1 updates available").arg(Packages.total) : Tr.tr("Up to date")
            subtext: Packages.checkedAt.getTime() > 0 ? Tr.tr("Last checked at %1").arg(Qt.formatTime(Packages.checkedAt, "HH:mm")) : ""
        }

        RowButton {
            Layout.fillWidth: true
            disabled: Packages.checking || Packages.updating
            icon: "refresh"
            text: Tr.tr("Check again")
            onClicked: Packages.check(true)
        }

        RowButton {
            Layout.fillWidth: true
            visible: Packages.total > 0 || Packages.updating
            disabled: Packages.checking || Packages.updating || root.chosen === 0
            icon: "download"
            text: Packages.updating ? Tr.tr("Updating…") : root.chosen === Packages.total ? Tr.tr("Update everything") : Tr.tr("Update the %1 chosen").arg(root.chosen)
            subtext: {
                if (!Packages.updating)
                    return Tr.tr("Asks for your password, then shows the progress here");
                const last = (Admin.outputOf(Packages.updateWhat).trim().split("\n").pop() ?? "").replace(/^\$ /, "").slice(0, 110);
                const step = Packages.updateStep === "repo" ? Tr.tr("System packages") : Packages.updateStep === "aur" ? Tr.tr("AUR packages") : Tr.tr("Flatpak apps");
                return last ? `${step}: ${last}` : step;
            }
            onClicked: root.updateChosen()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: Packages.total > 1 && !Packages.updating
            spacing: Tokens.spacing.small

            TextButton {
                text: Tr.tr("Choose all")
                type: TextButton.Text
                onClicked: root.setAll(true)
            }

            TextButton {
                text: Tr.tr("Choose none")
                type: TextButton.Text
                onClicked: root.setAll(false)
            }
        }

        UpdateSection {
            title: Tr.tr("System packages")
            source: "repo"
            note: Tr.tr("Arch updates system packages together: an unticked one is kept back this time (pacman --ignore), which can break apps that need its new version.")
            items: Packages.repo
        }

        UpdateSection {
            title: "AUR"
            source: "aur"
            items: Packages.aur
        }

        UpdateSection {
            title: "Flatpak"
            source: "flatpak"
            items: Packages.flatpak
        }

        // Kept at their version
        SectionHeader {
            visible: Packages.held.length > 0
            text: Tr.tr("Kept at their version")
        }

        Repeater {
            model: Packages.held

            RowButton {
                required property string modelData

                Layout.fillWidth: true
                icon: "lock"
                text: modelData
                subtext: Tr.tr("Left out of updates · tap to update it again")
                onClicked: Packages.hold(modelData, false)
            }
        }

        // Configuration files an update brought
        SectionHeader {
            visible: root.pacnew.length > 0
            text: Tr.tr("Configuration changes waiting")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.pacnew.length > 0
            text: Tr.tr("An update brought a new version of these files but kept yours (you may have changed it). Look at the difference, then keep the new one or yours.")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Repeater {
            model: root.pacnew

            ColumnLayout {
                id: pn

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                RowButton {
                    Layout.fillWidth: true
                    icon: "difference"
                    text: pn.modelData.original
                    subtext: (pn.modelData.kind === "pacsave" ? Tr.tr("Saved when its package was removed") : Tr.tr("New version from %1").arg(Qt.formatDate(new Date(pn.modelData.date * 1000), "d MMM yyyy"))) + (root.pacnewOpen?.path === pn.modelData.path ? "" : " · " + Tr.tr("tap to see the difference"))
                    trailingIcon: root.pacnewOpen?.path === pn.modelData.path ? "expand_less" : "expand_more"
                    onClicked: {
                        if (root.pacnewOpen?.path === pn.modelData.path) {
                            root.pacnewOpen = null;
                            return;
                        }
                        root.pacnewOpen = pn.modelData;
                        root.pacnewDiff = Tr.tr("Reading…");
                        diffProc.command = [Packages.helper, "pacdiff", pn.modelData.path];
                        diffProc.running = true;
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    visible: root.pacnewOpen?.path === pn.modelData.path
                    implicitHeight: Math.min(diffText.implicitHeight + Tokens.padding.medium * 2, 360)
                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceContainerHigh
                    clip: true

                    StyledFlickable {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        contentHeight: diffText.implicitHeight
                        contentWidth: width

                        StyledText {
                            id: diffText

                            width: parent.width
                            text: root.pacnewDiff || Tr.tr("No difference")
                            wrapMode: Text.WrapAnywhere
                            font: Tokens.font.mono.small
                            textFormat: Text.PlainText
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing.small
                    visible: root.pacnewOpen?.path === pn.modelData.path
                    spacing: Tokens.spacing.small

                    TextButton {
                        text: pn.modelData.kind === "pacsave" ? Tr.tr("Put it back") : Tr.tr("Use the new one")
                        type: TextButton.Tonal
                        onClicked: Admin.run("pacnew", [pn.modelData.path, "keep-new"], Tr.tr("Use the new %1").arg(pn.modelData.original), () => root.loadExtras())
                    }

                    TextButton {
                        text: pn.modelData.kind === "pacsave" ? Tr.tr("Delete it") : Tr.tr("Keep mine")
                        type: TextButton.Tonal
                        onClicked: Admin.run("pacnew", [pn.modelData.path, "keep-old"], Tr.tr("Keep your %1").arg(pn.modelData.original), () => root.loadExtras())
                    }
                }
            }
        }

        // Arch news (manual steps some updates need are announced here)
        SectionHeader {
            visible: root.news.length > 0
            text: Tr.tr("Arch Linux news")
        }

        Repeater {
            model: root.showAllNews ? root.news : root.news.slice(0, 3)

            RowButton {
                required property var modelData

                Layout.fillWidth: true
                icon: "newspaper"
                text: modelData.title
                subtext: `${Qt.formatDate(new Date(modelData.date), "d MMM yyyy")} · ${modelData.summary}`
                trailingIcon: "open_in_new"
                onClicked: Qt.openUrlExternally(modelData.link)
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: !root.showAllNews && root.news.length > 3
            icon: "expand_more"
            text: Tr.tr("Show all %1").arg(root.news.length)
            onClicked: root.showAllNews = true
        }

        // Automatic checks
        SectionHeader {
            text: Tr.tr("Automatic checks")
        }

        SelectRow {
            label: Tr.tr("Check for updates")
            menuItems: root.checkItems
            active: root.checkItems.find(i => i.value === GlobalConfig.services.updateCheckHours) ?? root.checkItems[3]
            onSelected: item => GlobalConfig.services.updateCheckHours = item.value
        }

        ToggleRow {
            text: Tr.tr("Notify me")
            subtext: Tr.tr("When updates are waiting, and when a restart is needed after one")
            checked: GlobalConfig.services.updateNotify
            onToggled: GlobalConfig.services.updateNotify = checked
        }

        Process {
            id: newsProc

            command: [Packages.helper, "news"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.news = JSON.parse(text).items ?? [];
                    } catch (e) {}
                }
            }
        }

        Process {
            id: pacnewProc

            command: [Packages.helper, "pacnew"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.pacnew = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }

        Process {
            id: diffProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(text);
                        root.pacnewDiff = d.error ? Tr.tr("Can't read it: %1").arg(d.error) : (d.diff + (d.truncated ? "\n…" : ""));
                    } catch (e) {}
                }
            }
        }
    }

    component UpdateSection: ColumnLayout {
        id: section

        required property string title
        required property string source
        required property var items
        property string note
        property bool showAll

        Layout.fillWidth: true
        visible: items.length > 0
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: `${section.title} (${section.items.length})`
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: !!section.note && section.items.some(u => root.skipped[`${section.source}:${u.appId || u.name}`])
            text: section.note
            wrapMode: Text.WordWrap
            color: Colours.palette.m3error
            font: Tokens.font.label.small
        }

        Repeater {
            model: section.showAll ? section.items : section.items.slice(0, 15)

            CheckRow {
                required property var modelData

                readonly property var u: Object.assign({
                    source: section.source
                }, modelData)

                label: modelData.name
                subtext: modelData.appId && modelData.appId !== modelData.name ? modelData.appId : ""
                value: modelData.from ? `${modelData.from} → ${modelData.to}` : modelData.to
                checked: !root.skipped[root.key(u)]
                disabled: Packages.updating
                onToggled: on => root.toggle(u, on)
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: !section.showAll && section.items.length > 15
            icon: "expand_more"
            text: Tr.tr("Show all %1").arg(section.items.length)
            onClicked: section.showAll = true
        }
    }
}
