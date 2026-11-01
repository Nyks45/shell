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

        Repeater {
            model: root.results

            StyledRect {
                id: item

                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

                color: index === 0 ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                radius: index === 0 ? Tokens.rounding.extraLarge : Tokens.rounding.medium

                StateLayer {
                    anchors.fill: parent
                    radius: parent.radius
                    onClicked: root.nState.goTo(item.modelData)
                }

                RowLayout {
                    id: layout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: item.modelData.icon || "tune"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        fill: item.modelData.icon ? 1 : 0
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: item.modelData.title
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text
                            text: item.modelData.where
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
