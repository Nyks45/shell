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

    // The visible row next to `row` (dir -1: above, +1: below), or null when
    // the group ends there
    function neighbour(row: Item, dir: int): Item {
        void revision;
        const h = host(row);
        const col = h?.parent;
        if (!col)
            return null;
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
            const k = kids[j];
            if (!k.visible)
                continue;
            const r = k.isGroupRow === true ? k : k.item?.isGroupRow === true ? k.item : null;
            if (r)
                return r;
            // Nothing to see (a Repeater; a Loader showing nothing): look
            // further. (Not by height: in a layout that would feed back
            // into the layout and loop.)
            if (k.delegate !== undefined && k.model !== undefined)
                continue;
            if (k.sourceComponent !== undefined && !k.item)
                continue;
            return null;
        }
        return null;
    }

    function isFirst(row: Item): bool {
        return !!row && (row.groupStart === true || !neighbour(row, -1));
    }

    function isLast(row: Item): bool {
        const n = neighbour(row, 1);
        return !n || n.groupStart === true;
    }
}
