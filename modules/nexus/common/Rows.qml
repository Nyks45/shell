pragma Singleton

import QtQuick

// Where a row sits in its group, for its rounded corners: rows next to each
// other in a column form one group (rounded at its top and bottom only); a
// section header, text or any other item ends it. Rows hidden by a condition
// don't count, so the corners stay right whatever is shown. A row with
// groupStart starts a new group even right after another row.
QtObject {
    id: rows

    // Bumped (once per batch) when rows are made or go away: rows check their
    // neighbours again once a whole page or list has been built (while it is
    // built, the row below may not exist yet)
    property int revision
    property bool pending

    function bump(): void {
        if (pending)
            return;
        pending = true;
        Qt.callLater(() => {
            rows.pending = false;
            rows.revision++;
        });
    }

    // The item that sits in the column: the row, or the Loader showing it
    function host(row: Item): Item {
        const p = row?.parent;
        return p && p.item === row ? p : row;
    }

    // What an item shown in a column is, seen from a row next to it (dir -1: from below, +1:
    // from above): a row (the nearest one in it), "none" (nothing to see: a Repeater, an empty
    // Loader or column) or "block" (anything else: a text, a picture... ends the group). A
    // column of rows (a component grouping a few, like a pair of steppers) is see-through:
    // its rows join the group around it.
    function edge(k: Item, dir: int): var {
        if (k.isGroupRow === true)
            return k;
        if (k.item?.isGroupRow === true)
            return k.item;
        // (a Repeater: its delegates are the column's own children)
        if (k.delegate !== undefined && k.model !== undefined)
            return "none";
        if (k.sourceComponent !== undefined)
            return k.item ? edge(k.item, dir) : "none";
        if (k.spacing !== undefined && k.children !== undefined) {
            const kids = k.children;
            for (let j = dir > 0 ? 0 : kids.length - 1; j >= 0 && j < kids.length; j += dir) {
                if (!kids[j].visible)
                    continue;
                const r = edge(kids[j], dir);
                if (r !== "none")
                    return r;
            }
            return "none";
        }
        return "block";
    }

    // The visible row next to `row` (dir -1: above, +1: below), or null when
    // the group ends there
    function neighbour(row: Item, dir: int): Item {
        void revision;
        let h = host(row);
        let col = h?.parent;
        while (col) {
            const kids = col.children;
            let i = -1;
            for (let k = 0; k < kids.length; k++) {
                if (kids[k] === h) {
                    i = k;
                    break;
                }
            }
            if (i < 0)
                return null;
            for (let j = i + dir; j >= 0 && j < kids.length; j += dir) {
                if (!kids[j].visible)
                    continue;
                const r = edge(kids[j], dir);
                if (r === "block")
                    return null;
                if (r !== "none")
                    return r;
            }
            // The end of a column inside another column: on into the outer one (its rows are
            // one group with the ones around it)
            if (col.spacing === undefined || col.parent?.spacing === undefined)
                return null;
            h = col;
            col = col.parent;
        }
        return null;
    }

    // The gap above a row (filled in when it continues a card): its column's spacing, or, for
    // the first row of a column inside another, the outer column's
    function gapAbove(row: Item): real {
        void revision;
        let h = host(row);
        let col = h?.parent;
        while (col && col.parent?.spacing !== undefined && col.spacing !== undefined) {
            const kids = col.children;
            let firstShown = null;
            for (let k = 0; k < kids.length; k++) {
                if (kids[k].visible && edge(kids[k], 1) !== "none") {
                    firstShown = kids[k];
                    break;
                }
            }
            if (firstShown !== h)
                break;
            h = col;
            col = col.parent;
        }
        return col?.spacing ?? 0;
    }

    function isFirst(row: Item): bool {
        return !!row && (row.groupStart === true || !neighbour(row, -1));
    }

    function isLast(row: Item): bool {
        const n = neighbour(row, 1);
        return !n || n.groupStart === true;
    }
}
