pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus

// The pages, as a tree like DankMaterialShell's settings: groups (an icon, a name and a
// chevron; a click folds it) with their pages under them; the page shown is a filled pill.
VerticalFadeFlickable {
    id: root

    required property NexusState nState

    // Categories folded away (by key), for as long as the window is open
    property var folded: ({})

    // Windows-like order: core hardware & system first, then devices & network,
    // personalisation, apps & gaming, account & preferences, updates & advanced.
    readonly property var groups: {
        const spec = [
            {
                key: "system",
                label: Tr.tr("System"),
                icon: "computer",
                ids: ["display", "audio", "notifications", "power", "storage", "recovery", "about"]
            },
            {
                key: "connect",
                label: Tr.tr("Devices & network"),
                icon: "devices_other",
                ids: ["devices", "network"]
            },
            {
                key: "personalise",
                label: Tr.tr("Personalisation"),
                icon: "palette",
                ids: ["wallpaper", "themes", "windows", "panels", "workspaces"]
            },
            {
                key: "apps",
                label: Tr.tr("Apps & gaming"),
                icon: "apps",
                ids: ["apps", "gaming"]
            },
            {
                key: "you",
                label: Tr.tr("Accounts & preferences"),
                icon: "person",
                ids: ["account", "time", "accessibility", "privacy"]
            },
            {
                key: "advanced",
                label: Tr.tr("Updates & advanced"),
                icon: "tune",
                ids: ["updates", "advanced"]
            }
        ];
        const used = new Set();
        const out = spec.map(g => {
            const pages = [];
            for (const id of g.ids) {
                const i = PageRegistry.find(id);
                if (i >= 0) {
                    used.add(i);
                    pages.push({
                        index: i,
                        page: PageRegistry.pages[i]
                    });
                }
            }
            return Object.assign({}, g, {
                pages: pages
            });
        });
        const rest = PageRegistry.pages.map((p, i) => ({
                    index: i,
                    page: p
                })).filter(e => !used.has(e.index));
        if (rest.length)
            out.push({
                key: "more",
                label: Tr.tr("More"),
                icon: "more_horiz",
                pages: rest
            });
        return out.filter(g => g.pages.length > 0);
    }

    function toggle(key: string): void {
        const next = Object.assign({}, folded);
        if (next[key])
            delete next[key];
        else
            next[key] = true;
        folded = next;
    }

    function ensureVisible(it: Item): void {
        Qt.callLater(() => {
            if (!it || root.height <= 0 || it.height <= 0)
                return;
            const pad = Tokens.padding.large;
            const top = it.mapToItem(contentItem, 0, 0).y;
            const bot = top + it.height;
            const minY = -topMargin;
            const maxY = Math.max(minY, contentHeight - height + bottomMargin);
            if (top < contentY + pad)
                contentY = Math.max(minY, top - pad);
            else if (bot > contentY + height - pad)
                contentY = Math.min(maxY, bot + pad - height);
        });
    }

    topMargin: Tokens.padding.small
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight
    onVisibleChanged: if (visible) {
        cancelFlick();
        contentY = clampY(contentY);
    }

    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        onTapped: root.focus = true
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall / 2

        Repeater {
            model: root.groups

            ColumnLayout {
                id: group

                required property var modelData
                required property int index
                readonly property bool open: !root.folded[modelData.key]
                readonly property bool hasCurrent: modelData.pages.some(p => p.index === root.nState.currentPageIdx)

                onHasCurrentChanged: if (hasCurrent && root.folded[modelData.key])
                    root.toggle(modelData.key)

                Layout.fillWidth: true
                Layout.topMargin: index === 0 ? 0 : Tokens.spacing.small
                spacing: Tokens.spacing.extraSmall / 2

                // The category
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: headRow.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: "transparent"

                    StateLayer {
                        onClicked: root.toggle(group.modelData.key)
                    }

                    RowLayout {
                        id: headRow

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: group.modelData.icon
                            color: group.hasCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: group.modelData.label
                            color: group.hasCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.large
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            text: "expand_less"
                            rotation: group.open ? 0 : 180
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small

                            Behavior on rotation {
                                Anim {}
                            }
                        }
                    }
                }

                // Its pages (folding away)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: group.open ? pageList.implicitHeight : 0
                    clip: true

                    Behavior on implicitHeight {
                        Anim {}
                    }

                    ColumnLayout {
                        id: pageList

                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Tokens.spacing.extraSmall / 2
                        opacity: group.open ? 1 : 0

                        Behavior on opacity {
                            Anim {}
                        }

                        Repeater {
                            model: group.modelData.pages

                            StyledRect {
                                id: item

                                required property var modelData
                                readonly property bool current: modelData.index === root.nState.currentPageIdx

                                onCurrentChanged: if (current)
                                    root.ensureVisible(item)
                                Component.onCompleted: if (current)
                                    root.ensureVisible(item)

                                Layout.fillWidth: true
                                implicitHeight: itemRow.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.full
                                color: current ? Colours.palette.m3primary : "transparent"

                                StateLayer {
                                    color: item.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    onClicked: root.nState.currentPageIdx = item.modelData.index
                                }

                                RowLayout {
                                    id: itemRow

                                    anchors.fill: parent
                                    anchors.leftMargin: Tokens.padding.largeIncreased + Tokens.padding.small
                                    anchors.rightMargin: Tokens.padding.medium
                                    spacing: Tokens.spacing.medium

                                    MaterialIcon {
                                        text: item.modelData.page.icon
                                        color: item.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.small
                                        fill: item.current ? 1 : 0
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: item.modelData.page.label
                                        color: item.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        font: Tokens.font.body.small
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
