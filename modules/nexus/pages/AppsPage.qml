pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // The system defaults (xdg-settings / xdg-mime), as desktop entry ids
    property string browserId
    property string editorId
    readonly property list<string> textTypes: ["text/plain", "text/markdown", "text/x-csrc", "text/x-chdr", "text/x-c++src", "text/x-c++hdr", "text/x-python", "text/x-shellscript", "application/x-shellscript", "application/json", "application/xml", "application/toml", "text/x-lua", "application/x-yaml", "text/x-log"]

    // A desktop entry's command for the config (no %u-style placeholders)
    function commandOf(app: DesktopEntry): string {
        return app.command.filter(a => !/^%[a-zA-Z]$/.test(a)).join(" ");
    }

    function nameOf(id: string): string {
        return DesktopEntries.byId(id.replace(/\.desktop$/, ""))?.name ?? id.replace(/\.desktop$/, "");
    }

    title: Tr.tr("Apps")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Default applications
        SectionHeader {
            first: true
            text: Tr.tr("Default applications")
        }

        DefaultRow {
            first: true
            icon: "terminal"
            label: Tr.trCtx("Terminal", "default app category")
            status: GlobalConfig.general.apps.terminal.join(" ")
            onSelected: app => GlobalConfig.general.apps.terminal = app.command
        }

        DefaultRow {
            icon: "volume_up"
            label: Tr.trCtx("Audio", "default app category")
            status: GlobalConfig.general.apps.audio.join(" ")
            onSelected: app => GlobalConfig.general.apps.audio = app.command
        }

        DefaultRow {
            icon: "play_circle"
            label: Tr.trCtx("Media playback", "default app category")
            status: GlobalConfig.general.apps.playback.join(" ")
            onSelected: app => GlobalConfig.general.apps.playback = app.command
        }

        DefaultRow {
            icon: "folder"
            label: Tr.trCtx("File manager", "default app category")
            status: GlobalConfig.general.apps.explorer.join(" ")
            onSelected: app => GlobalConfig.general.apps.explorer = app.command
        }

        DefaultRow {
            icon: "language"
            label: Tr.trCtx("Web browser", "default app category")
            category: "WebBrowser"
            status: root.browserId ? root.nameOf(root.browserId) : Tr.tr("Not set")
            onSelected: app => {
                root.browserId = `${app.id}.desktop`;
                HyprSettings.setVar("browser", root.commandOf(app));
                Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", `${app.id}.desktop`]);
            }
        }

        DefaultRow {
            last: true
            icon: "edit_note"
            label: Tr.trCtx("Text editor", "default app category")
            category: "TextEditor"
            status: root.editorId ? root.nameOf(root.editorId) : Tr.tr("Not set")
            onSelected: app => {
                root.editorId = `${app.id}.desktop`;
                HyprSettings.setVar("editor", root.commandOf(app));
                Quickshell.execDetached(["xdg-mime", "default", `${app.id}.desktop`, ...root.textTypes]);
            }
        }

        // Library
        SectionHeader {
            text: Tr.trCtx("Library", "app library")
        }

        NavRow {
            first: true
            last: true
            icon: "apps"
            text: Tr.tr("All apps")
            subtext: Tr.tr("Browse installed apps, set favourites and hidden")
            onClicked: root.nState.openSubPage(1)
        }

        // Non-visual helpers (the page takes one item: they live in its column)
        Process {
            running: true
            command: ["sh", "-c", "xdg-settings get default-web-browser; xdg-mime query default text/plain"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const [browser, editor] = text.split("\n");
                    root.browserId = browser?.trim() ?? "";
                    root.editorId = editor?.trim() ?? "";
                }
            }
        }
    }

    component DefaultRow: PopupRow {
        id: row

        // Only apps of this kind (a desktop file category), when there are any
        property string category

        readonly property int popupHeight: root.flickable.height - y + root.flickable.contentY - Tokens.padding.large - Tokens.padding.extraExtraLarge

        signal selected(app: DesktopEntry)

        keepPopupAsChild: {
            if (root.nState.animatingContainer || root.opacity < 1)
                return true;

            let p = root.parent;
            while (p && p.objectName !== "PageContainer")
                p = p.parent;
            return p?.opacity < 1;
        }
        popup.topMovement: Math.max(Tokens.sizes.nexus.minPopupHeight - popupHeight, Tokens.padding.large)

        Loader {
            anchors.centerIn: parent
            active: row.popup.animDriver > 0

            sourceComponent: VerticalFadeListView {
                id: list

                implicitWidth: Tokens.sizes.nexus.popupWidth
                // As tall as its items (a short list doesn't get an empty tail), up to the usual height
                implicitHeight: Math.min(contentHeight + topMargin + bottomMargin, CUtils.clamp(row.popupHeight, Tokens.sizes.nexus.minPopupHeight, Tokens.sizes.nexus.maxPopupHeight))

                model: {
                    const all = [...DesktopEntries.applications.values];
                    const ofKind = row.category ? all.filter(a => a.categories.includes(row.category)) : [];
                    const apps = ofKind.length > 0 ? ofKind : all;
                    const favourited = new Set(apps.filter(a => Strings.testRegexList(GlobalConfig.launcher.favouriteApps, a.id)));
                    return apps.sort((a, b) => (favourited.has(b) - favourited.has(a)) || a.name.localeCompare(b.name));
                }

                delegate: StateLayer {
                    id: appItem

                    required property DesktopEntry modelData
                    required property int index

                    anchors.fill: undefined
                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    implicitHeight: itemLayout.implicitHeight + itemLayout.anchors.margins * 2
                    radius: Tokens.rounding.small

                    onClicked: {
                        row.popup.open = false;
                        row.selected(modelData);
                    }

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        IconImage {
                            asynchronous: true
                            implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                            source: Quickshell.iconPath(appItem.modelData.icon, "image-missing")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: appItem.modelData.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text
                                text: (appItem.modelData.comment || appItem.modelData.genericName) ?? ""
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        MaterialIcon {
                            visible: Strings.testRegexList(GlobalConfig.launcher.favouriteApps, appItem.modelData.id)
                            text: "favorite"
                            fill: 1
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.small
                        }
                    }
                }
            }
        }
    }
}
