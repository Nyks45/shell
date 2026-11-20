pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// What's installed: apps (with a launcher entry), everything installed on
// purpose, AUR packages, Flatpak apps; find, sort, open one to remove it,
// keep it at its version or go back to an older one.
PageBase {
    id: root

    // "apps", "explicit", "aur", "flatpak"
    property string filter: "apps"
    // "name", "size", "recent"
    property string sort: "name"
    property string pendingSearch
    property string search
    property int limit: 30

    readonly property var all: Packages.installed?.packages ?? []
    readonly property var shown: {
        const q = search.toLowerCase();
        const list = all.filter(p => {
            if (filter === "apps" && (p.apps ?? []).length === 0)
                return false;
            if (filter === "aur" && p.source !== "aur")
                return false;
            if (filter === "flatpak" && p.source !== "flatpak")
                return false;
            if (filter === "explicit" && p.source === "flatpak")
                return false;
            return !q || `${p.name} ${p.desc} ${(p.apps ?? []).join(" ")}`.toLowerCase().includes(q);
        });
        if (sort === "size")
            list.sort((a, b) => (b.size ?? 0) - (a.size ?? 0));
        else if (sort === "recent")
            list.sort((a, b) => (b.installDate ?? 0) - (a.installDate ?? 0));
        else
            list.sort((a, b) => Packages.displayName(a).localeCompare(Packages.displayName(b)));
        return list;
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

    title: Tr.tr("Installed")

    Component.onCompleted: if (!Packages.installed)
        Packages.loadInstalled()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        InfoRow {
            icon: "inventory_2"
            label: Packages.installed ? Tr.tr("%1 packages installed").arg(Packages.installed.totalPackages) : Tr.tr("Reading…")
            subtext: {
                if (!Packages.installed)
                    return "";
                const explicitCount = root.all.filter(p => p.source !== "flatpak" && p.explicit).length;
                const aurCount = root.all.filter(p => p.source === "aur").length;
                const flatpakCount = root.all.filter(p => p.source === "flatpak").length;
                return Tr.tr("%1 installed explicitly · %2 from AUR · %3 Flatpak").arg(explicitCount).arg(aurCount).arg(flatpakCount);
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            Repeater {
                model: [["apps", Tr.tr("Apps")], ["explicit", Tr.tr("All you installed")], ["aur", "AUR"], ["flatpak", "Flatpak"]]

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.filter === modelData[0]
                    type: TextButton.Tonal
                    onClicked: {
                        root.filter = modelData[0];
                        root.limit = 30;
                    }
                }
            }
        }

        StyledTextField {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            placeholderText: Tr.tr("Find an installed app or package")
            leadingIcon: "search"
            onTextChanged: {
                root.pendingSearch = text;
                searchDelay.restart();
            }
        }

        Timer {
            id: searchDelay

            interval: 200
            onTriggered: {
                root.limit = 30;
                root.search = root.pendingSearch;
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            spacing: Tokens.spacing.small

            Repeater {
                model: [["name", Tr.tr("Sort: Name")], ["size", Tr.tr("Size")], ["recent", Tr.tr("Recent")]]

                TextButton {
                    required property var modelData

                    text: modelData[1]
                    isToggle: true
                    followChecked: true
                    checked: root.sort === modelData[0]
                    type: TextButton.Tonal
                    onClicked: {
                        root.sort = modelData[0];
                        root.limit = 30;
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: !!Packages.installed && root.shown.length === 0
            text: Tr.tr("Nothing here")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.shown.slice(0, root.limit)

            PackageRow {
                required property var modelData

                item: Object.assign({
                    installed: true
                }, modelData)
                nState: root.nState
                showInstall: false
                detail: [root.sort === "recent" && modelData.installDate ? Qt.formatDate(new Date(modelData.installDate * 1000), "d MMM yyyy") : "", root.size(modelData.size) || modelData.sizeText || "", modelData.held ? Tr.tr("kept at this version") : ""].filter(s => s).join(" · ")
            }
        }

        RowButton {
            Layout.fillWidth: true
            visible: root.shown.length > root.limit
            icon: "expand_more"
            text: Tr.tr("Show %1 more").arg(Math.min(30, root.shown.length - root.limit))
            subtext: Tr.tr("Showing %1 of %2").arg(Math.min(root.limit, root.shown.length)).arg(root.shown.length)
            onClicked: root.limit += 30
        }
    }
}
