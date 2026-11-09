pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

// One app or package (search results, popular apps, installed): its icon,
// name, where it comes from and what it is; Install right there, or open its
// page (PackagePage) with everything else.
ConnectedRect {
    id: root

    required property var item
    required property NexusState nState
    // An Install button for packages not installed yet
    property bool showInstall: true
    // A line of its own instead of the description (sizes, dates)
    property string detail

    readonly property string busy: Packages.busy[Packages.key(item)] ?? ""
    // Its launcher entry when it has one (the icon and name people know)
    readonly property DesktopEntry entry: Packages.entryOf(item)
    readonly property string iconSource: {
        if (item.icon)
            return `file://${item.icon}`;
        if (item.iconName && Quickshell.iconPath(item.iconName, true))
            return Quickshell.iconPath(item.iconName, true);
        if (entry?.icon)
            return Quickshell.iconPath(entry.icon, true);
        return Quickshell.iconPath(item.name, true);
    }

    function sourceText(): string {
        if (item.source === "flatpak")
            return "Flathub";
        if (item.source === "aur")
            return "AUR";
        if (item.source === "local")
            return Tr.tr("Local");
        return item.repo ? Tr.tr("System · %1").arg(item.repo) : Tr.tr("System");
    }

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

    StateLayer {
        onClicked: {
            root.nState.selectedPackage = {
                source: root.item.source,
                name: root.item.appId || root.item.name,
                title: root.item.name
            };
            root.nState.openSubPage(3);
        }
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        Item {
            implicitWidth: Math.round(Tokens.font.icon.large.pointSize * 1.8)
            implicitHeight: implicitWidth

            IconImage {
                anchors.fill: parent
                visible: !!root.iconSource
                asynchronous: true
                source: root.iconSource
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !root.iconSource
                text: root.item.source === "flatpak" ? "apps" : "package_2"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                readonly property string shownName: root.entry?.name || root.item.title || ""
                text: !shownName || root.item.source === "flatpak" ? root.item.name : shownName.toLowerCase() === root.item.name.toLowerCase() ? shownName : `${shownName} (${root.item.name})`
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: [root.sourceText(), root.item.version ?? "", root.detail || root.item.desc || root.entry?.comment || ""].filter(s => s).join(" · ")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: !!root.busy
            text: root.busy === "remove" ? Tr.tr("Removing…") : Tr.tr("Installing…")
            color: Colours.palette.m3primary
            font: Tokens.font.label.small
        }

        StyledText {
            visible: !root.busy && root.item.installed && root.showInstall
            text: Tr.tr("Installed")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }

        TextButton {
            visible: !root.busy && !root.item.installed && root.showInstall
            text: Tr.trCtx("Install", "button")
            type: TextButton.Tonal
            onClicked: Packages.install(root.item)
        }

        MaterialIcon {
            text: "chevron_right"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
        }
    }
}
