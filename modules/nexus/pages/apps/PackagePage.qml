pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// One app or package (nState.selectedPackage): what it is, install / open /
// update / remove, its details, keeping it at its version and going back
// to an older one from the package cache.
PageBase {
    id: root

    readonly property var sel: nState.selectedPackage
    // caelestia-packages info
    property var info: null
    // Older versions in the cache: [{ version, file, current }]
    property var versions: []
    property bool keepDeps

    readonly property bool installed: !!info?.installed
    readonly property string busy: sel ? (Packages.busy[`${sel.source}:${sel.name}`] ?? "") : ""
    readonly property var item: info ? Object.assign({}, info, {
        source: info.source === "local" ? "aur" : info.source,
        name: info.source === "flatpak" ? (info.name || sel.title) : info.name,
        appId: info.source === "flatpak" ? sel.name : ""
    }) : null
    readonly property var update: {
        if (!sel)
            return null;
        const list = sel.source === "flatpak" ? Packages.flatpak : sel.source === "aur" ? Packages.aur : Packages.repo;
        return list.find(u => (u.appId || u.name) === sel.name) ?? null;
    }
    readonly property DesktopEntry entry: Packages.entryOf(info ? Object.assign({
        appId: sel?.source === "flatpak" ? sel.name : ""
    }, info) : null)
    readonly property bool canHold: installed && sel?.source !== "flatpak"

    function load(): void {
        if (!sel)
            return;
        infoProc.command = [Packages.helper, "info", sel.source, sel.name];
        infoProc.running = true;
        if (sel.source !== "flatpak") {
            versionsProc.command = [Packages.helper, "versions", sel.name];
            versionsProc.running = true;
        }
    }

    function size(bytes: real): string {
        if (!bytes)
            return "";
        const u = GlobalConfig.services.dataUnits === DataUnit.Decimal ? 1000 : 1024;
        const names = u === 1000 ? ["B", "kB", "MB", "GB"] : ["B", "KiB", "MiB", "GiB"];
        let i = 0;
        while (bytes >= u && i < names.length - 1) {
            bytes /= u;
            i++;
        }
        return `${bytes.toFixed(i > 1 ? 1 : 0)} ${names[i]}`;
    }

    function sourceText(): string {
        if (!info)
            return "";
        if (info.source === "flatpak")
            return `Flathub${info.origin && info.origin !== "flathub" ? ` (${info.origin})` : ""}`;
        if (info.source === "aur")
            return Tr.tr("AUR (community)");
        if (info.source === "local")
            return Tr.tr("Installed from a file (not in any repository)");
        return Tr.tr("System repository %1").arg(info.repo ?? "");
    }

    title: sel?.title ?? Tr.tr("Package")
    isSubPage: true

    Component.onCompleted: load()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.large
            spacing: Tokens.spacing.large

            Item {
                implicitWidth: Math.round(Tokens.font.icon.large.pointSize * 3)
                implicitHeight: implicitWidth

                readonly property string src: root.info?.icon ? `file://${root.info.icon}` : root.info?.iconName && Quickshell.iconPath(root.info.iconName, true) ? Quickshell.iconPath(root.info.iconName, true) : root.entry?.icon ? Quickshell.iconPath(root.entry.icon, true) : Quickshell.iconPath(root.sel?.name ?? "", true)

                IconImage {
                    anchors.fill: parent
                    visible: !!parent.src
                    asynchronous: true
                    source: parent.src
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !parent.src
                    text: "package_2"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.entry?.name || root.info?.title || root.info?.name || root.sel?.title || ""
                    font: Tokens.font.title.medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text
                    text: root.info ? (root.info.summary || root.info.desc || root.entry?.comment || "") : Tr.tr("Reading…")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Actions
        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.large
            visible: !!root.info
            spacing: Tokens.spacing.small

            TextButton {
                visible: !root.installed && !root.busy
                text: Tr.trCtx("Install", "button")
                type: TextButton.Filled
                onClicked: Packages.install(root.item)
            }

            TextButton {
                visible: !!root.entry && root.installed && !root.busy
                text: Tr.trCtx("Open", "button")
                type: TextButton.Filled
                onClicked: root.entry.execute()
            }

            TextButton {
                visible: !!root.update && root.sel?.source !== "repo" && !Packages.updating && !root.busy
                text: Tr.tr("Update to %1").arg(root.update?.to ?? "")
                type: TextButton.Tonal
                onClicked: Packages.update([...Packages.repo.map(u => u.name)], root.sel.source === "aur" ? [root.sel.name] : [], root.sel.source === "flatpak" ? [root.sel.name] : [])
            }

            TextButton {
                visible: root.installed && !root.busy
                text: Tr.trCtx("Remove", "button")
                type: TextButton.Tonal
                onClicked: removeDialog.open = true
            }

            StyledText {
                visible: !!root.busy
                text: root.busy === "remove" ? Tr.tr("Removing… (the progress is in the notification if it fails)") : Tr.tr("Installing…")
                color: Colours.palette.m3primary
                font: Tokens.font.body.small
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.medium
            visible: !!root.update && root.sel?.source === "repo"
            text: Tr.tr("Version %1 is waiting: system packages are updated together, in Updates.").arg(root.update?.to ?? "")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3primary
            font: Tokens.font.label.small
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.medium
            visible: root.info?.source === "aur"
            text: Tr.tr("From the AUR: a recipe shared by the community and built on this computer, not checked by Arch.") + (root.info?.outOfDate ? " " + Tr.tr("Marked out of date.") : "")
            wrapMode: Text.WordWrap
            color: root.info?.outOfDate ? Colours.palette.m3error : Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        DialogRowButton {
            id: removeDialog

            visible: false
            rootParent: root.flickable
            openHeight: Math.min(root.flickable.height * 0.9, 330)
            icon: "delete"
            label: ""
            header: Tr.tr("Remove %1?").arg(root.entry?.name || root.info?.name || root.sel?.title || "")
            acceptLabel: Tr.trCtx("Remove", "button")
            content: Component {
                ColumnLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.medium
                        text: root.sel?.source === "flatpak" ? Tr.tr("The app is removed; its data in your home folder stays.") : (root.info?.requiredBy?.length ?? 0) > 0 ? Tr.tr("Needed by %1: those would be removed too, so this may be refused.").arg(root.info.requiredBy.join(", ")) : Tr.tr("Your files and settings in your home folder stay.")
                        wrapMode: Text.WordWrap
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }

                    ToggleRow {
                        visible: root.sel?.source !== "flatpak"
                        text: Tr.tr("Remove what only it needed")
                        subtext: Tr.tr("Dependencies nothing else uses")
                        checked: !root.keepDeps
                        onToggled: root.keepDeps = !checked
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            onAccepted: Packages.remove(root.item, root.keepDeps)
        }

        SectionHeader {
            first: true
            visible: !!root.info
            text: Tr.tr("Details")
        }

        InfoRow {
            visible: !!root.info
            label: Tr.tr("Version")
            value: root.installed ? (root.info?.installedVersion ?? "") + (root.info?.version && root.info.version !== root.info.installedVersion ? `  (${Tr.tr("available")} ${root.info.version})` : "") : (root.info?.version ?? "")
        }

        InfoRow {
            visible: !!root.info
            label: Tr.tr("From")
            value: root.sourceText()
        }

        InfoRow {
            visible: !!(root.info?.size || root.info?.installedSize || root.info?.downloadSize)
            label: Tr.tr("Size")
            value: root.info?.size ? root.size(root.info.size) + (root.info.download && !root.installed ? `  (${Tr.tr("download")} ${root.size(root.info.download)})` : "") : (root.info?.installedSize || root.info?.downloadSize || "")
        }

        InfoRow {
            visible: !!root.info?.installDate
            label: Tr.tr("Installed on")
            value: root.info?.installDate ? Qt.formatDate(new Date(root.info.installDate * 1000), "d MMMM yyyy") : ""
        }

        InfoRow {
            visible: !!(root.info?.license || (root.info?.licenses ?? []).length)
            label: Tr.tr("Licence")
            value: root.info?.license || (root.info?.licenses ?? []).join(", ")
        }

        InfoRow {
            visible: root.info?.source === "aur" && !!root.info?.maintainer
            label: Tr.tr("Maintainer")
            value: `${root.info?.maintainer ?? ""} · ${Tr.tr("%1 votes").arg(root.info?.votes ?? 0)}`
        }

        InfoRow {
            visible: !!root.info?.runtime
            label: Tr.tr("Runtime")
            value: root.info?.runtime ?? ""
        }

        RowButton {
            Layout.fillWidth: true
            visible: !!root.info?.url
            icon: "open_in_new"
            text: Tr.tr("Website")
            subtext: root.info?.url ?? ""
            onClicked: Qt.openUrlExternally(root.info.url)
        }

        RowButton {
            Layout.fillWidth: true
            visible: !!root.info?.aurPage
            icon: "open_in_new"
            text: Tr.tr("Its AUR page")
            subtext: Tr.tr("Comments, the recipe (PKGBUILD), its history")
            onClicked: Qt.openUrlExternally(root.info.aurPage)
        }

        // Updates
        SectionHeader {
            visible: root.canHold
            text: Tr.tr("Updates")
        }

        ToggleRow {
            visible: root.canHold
            text: Tr.tr("Keep at this version")
            subtext: Tr.tr("Left out of updates until you turn this off")
            checked: !!root.info?.held
            onToggled: Packages.hold(root.sel.name, checked)
        }

        Repeater {
            model: root.installed ? root.versions.filter(v => !v.current) : []

            RowButton {
                required property var modelData

                Layout.fillWidth: true
                icon: "history"
                text: Tr.tr("Go back to %1").arg(modelData.version)
                subtext: Tr.tr("From the package cache (%1); the password prompt asks").arg(Qt.formatDate(new Date(modelData.date * 1000), "d MMM yyyy"))
                onClicked: Admin.run("downgrade", [modelData.file], Tr.tr("Install %1 %2").arg(root.sel.name).arg(modelData.version), () => {
                    Packages.afterChange();
                })
            }
        }

        // What it needs and what needs it
        SectionHeader {
            visible: (root.info?.requiredBy?.length ?? 0) > 0 || (root.info?.depends?.length ?? 0) > 0
            text: Tr.tr("Dependencies")
        }

        InfoRow {
            visible: (root.info?.requiredBy?.length ?? 0) > 0
            label: Tr.tr("Needed by")
            subtext: (root.info?.requiredBy ?? []).join(", ")
        }

        InfoRow {
            visible: (root.info?.depends?.length ?? 0) > 0
            label: Tr.tr("Needs")
            subtext: (root.info?.depends ?? []).join(", ")
        }

        InfoRow {
            visible: (root.info?.optdepends?.length ?? 0) > 0
            label: Tr.tr("Works better with")
            subtext: (root.info?.optdepends ?? []).join("\n")
        }

        Process {
            id: infoProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.info = JSON.parse(text);
                    } catch (e) {}
                }
            }
        }

        Process {
            id: versionsProc

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.versions = JSON.parse(text).versions ?? [];
                    } catch (e) {}
                }
            }
        }

        Connections {
            target: Packages

            function onChanged(): void {
                root.load();
            }
        }
    }
}
