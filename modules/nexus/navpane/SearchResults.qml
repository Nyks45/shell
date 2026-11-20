pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus

// What the settings search finds: matching pages first, then the settings on
// them (from SearchIndex). Picking one opens its page (and sub-page) and
// flashes the setting.
VerticalFadeFlickable {
    id: root

    required property NexusState nState
    readonly property string query: nState.searchText.trim().toLowerCase()
    readonly property var results: query ? search(query) : []

    function tr(text: string, ctx: string): string {
        return ctx ? Tr.trCtx(text, ctx) : Tr.tr(text);
    }

    // Every word has to appear somewhere (label, subtext, section, page names,
    // keywords); a label that starts with the query ranks first.
    function search(q: string): var {
        const words = q.split(/\s+/).filter(w => w);
        const scored = [];
        const score = (label, haystack) => {
            if (!words.every(w => haystack.includes(w)))
                return -1;
            const l = label.toLowerCase();
            if (l === q)
                return 0;
            if (l.startsWith(q))
                return 1;
            if (words.every(w => l.includes(w)))
                return 2;
            return 3;
        };

        PageRegistry.pages.forEach((p, idx) => {
            const s = score(p.label, `${p.label} ${p.description} ${p.keywords ?? ""}`.toLowerCase());
            if (s >= 0)
                scored.push({
                    score: s - 0.5, // pages before settings of the same rank
                    page: idx,
                    path: [],
                    title: p.label,
                    where: p.description,
                    icon: p.icon
                });
        });

        for (const e of SearchIndex.entries) {
            const label = tr(e.label, e.ctx);
            const page = PageRegistry.pages[e.page];
            const trail = e.trail.map(t => Tr.tr(t));
            const section = e.section ? Tr.tr(e.section) : "";
            const sub = e.sub ? Tr.tr(e.sub) : "";
            const hay = `${label} ${e.label} ${sub} ${section} ${page.label} ${trail.join(" ")} ${e.keywords}`.toLowerCase();
            const s = score(label, hay);
            if (s < 0)
                continue;
            // A generic label ("Enabled", "Show on hover") reads with its place
            const where = [page.label, ...trail, section].filter(x => x && x !== label).join(" › ");
            const opens = e.opens !== undefined;
            scored.push({
                score: opens ? s - 0.5 : s, // a sub-page is a page
                page: e.page,
                // A row that opens a sub-page opens it, rather than flashing the row
                path: opens ? e.path.concat([e.opens]) : e.path,
                tab: e.tab ?? "",
                title: label,
                where: opens && sub ? sub : where,
                icon: opens ? page.icon : "",
                text: opens ? "" : label,
                sectionText: section
            });
        }

        scored.sort((a, b) => a.score - b.score);
        // The same setting reached twice (e.g. one label under two sections) stays
        const seen = new Set();
        return scored.filter(r => {
            const key = `${r.page}/${r.path.join(".")}/${r.title}/${r.where}`;
            if (seen.has(key))
                return false;
            seen.add(key);
            return true;
        }).slice(0, 60);
    }

    function openFirst(): void {
        if (results.length > 0)
            nState.goTo(results[0]);
    }

    contentHeight: content.implicitHeight
    clip: true

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.padding.large
            visible: root.query && root.results.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Tr.tr("No settings match \"%1\"").arg(root.nState.searchText.trim())
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        // Grouped by page like the pages' tree (the page with the best match first); the first
        // match is a filled pill (Enter opens it)
        Repeater {
            model: {
                const groups = [];
                root.results.forEach((r, i) => {
                    let g = groups.find(x => x.page === r.page);
                    if (!g) {
                        g = {
                            page: r.page,
                            items: []
                        };
                        groups.push(g);
                    }
                    g.items.push(Object.assign({}, r, {
                        rank: i
                    }));
                });
                return groups;
            }

            ColumnLayout {
                id: group

                required property var modelData
                required property int index
                readonly property var page: PageRegistry.pages[modelData.page]

                Layout.fillWidth: true
                Layout.topMargin: index === 0 ? Tokens.padding.small : Tokens.spacing.small
                spacing: Tokens.spacing.extraSmall / 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.medium
                    Layout.rightMargin: Tokens.padding.medium
                    Layout.topMargin: Tokens.padding.extraSmall
                    Layout.bottomMargin: Tokens.padding.extraSmall
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: group.page?.icon ?? "tune"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: group.page?.label ?? ""
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.large
                        elide: Text.ElideRight
                    }
                }

                Repeater {
                    model: group.modelData.items

                    StyledRect {
                        id: item

                        required property var modelData
                        readonly property bool best: modelData.rank === 0
                        // The place, without the page's name (it's the group's)
                        readonly property string where: {
                            const w = modelData.where ?? "";
                            const name = group.page?.label ?? "";
                            return w.startsWith(name + " › ") ? w.slice(name.length + 3) : w === name ? "" : w;
                        }

                        Layout.fillWidth: true
                        implicitHeight: layout.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: best ? Colours.palette.m3primary : "transparent"

                        StateLayer {
                            color: item.best ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            onClicked: root.nState.goTo(item.modelData)
                        }

                        RowLayout {
                            id: layout

                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.largeIncreased + Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: item.modelData.path.length === 0 ? (item.modelData.icon || "tune") : item.modelData.icon ? "subdirectory_arrow_right" : "tune"
                                color: item.best ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.small
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: item.modelData.title
                                    color: item.best ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text
                                    text: item.where
                                    color: item.best ? Qt.alpha(Colours.palette.m3onPrimary, 0.75) : Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
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
