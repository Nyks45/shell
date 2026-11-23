pragma Singleton

import QtQuick
import QtQuick.Layouts

// Where a row sits in its group, for its rounded corners: rows next to each
// other in a column form one group (rounded at its top and bottom only); a
// section header, text or any other item ends it. Rows hidden by a condition
// don't count, so the corners stay right whatever is shown. A row with
// groupStart starts a new group even right after another row.
//
// Computed in a single O(n) pass per top-level column (and invalidated per
// column) so adding/removing rows on one page never rescans other pages.
// Uses integer row IDs on plain JS objects rather than Map/WeakMap with QObject
// keys, which triggers a Qt 6.12 QV4 sameValueZero crash across page teardown.
QtObject {
    id: rows

    // Plain JS state objects (no QML NOTIFY signals) so reading/updating flags
    // during binding evaluation never creates spurious dependencies or loops.
    readonly property var _state: ({
        nextId: 1,
        globalPending: false
    })
    readonly property var _trackers: []
    readonly property var _trackerByRowId: ({})

    function nextId(): int {
        return _state.nextId++;
    }

    readonly property Component trackerComp: Component {
        QtObject {
            id: tracker

            property Item topCol
            readonly property var _st: ({
                disposed: false,
                pending: false
            })
            property var info: ({})
            readonly property var _unsubs: []
            readonly property var _bumpFn: () => tracker.bump()

            function clearWatchers(): void {
                while (_unsubs.length > 0) {
                    const fn = _unsubs.pop();
                    try {
                        fn();
                    } catch (e) {}
                }
            }

            function recompute(): void {
                if (_st.disposed || !topCol)
                    return;
                clearWatchers();
                info = rows.computeColumn(topCol, _bumpFn, _unsubs);
            }

            function bump(): void {
                if (_st.disposed || _st.pending)
                    return;
                _st.pending = true;
                Qt.callLater(() => {
                    if (!tracker || tracker._st.disposed)
                        return;
                    tracker._st.pending = false;
                    tracker.recompute();
                });
            }

            Component.onDestruction: {
                _st.disposed = true;
                clearWatchers();
                const idx = rows._trackers.indexOf(tracker);
                if (idx >= 0)
                    rows._trackers.splice(idx, 1);
            }
        }
    }

    function watch(owner: var, sig: var, fn: var, unsubs: var): void {
        if (!owner || !sig || typeof sig.connect !== "function")
            return;
        sig.connect(fn);
        unsubs.push(() => {
            if (owner)
                sig.disconnect(fn);
        });
    }

    function findTracker(topCol: Item): var {
        if (!topCol)
            return null;
        for (let i = _trackers.length - 1; i >= 0; i--) {
            const t = _trackers[i];
            if (!t || !t._st || t._st.disposed || !t.topCol) {
                _trackers.splice(i, 1);
                continue;
            }
            if (t.topCol === topCol)
                return t;
        }
        return null;
    }

    function bump(item = null): void {
        if (item) {
            const id = item._rowsId ?? 0;
            const byIdTracker = id > 0 ? _trackerByRowId[id] : null;
            const t = (byIdTracker?._st && !byIdTracker._st.disposed && byIdTracker.topCol) ? byIdTracker : findTracker(topColumn(item, true));
            if (t?._st && !t._st.disposed && t.topCol) {
                t.bump();
                return;
            }
        }
        if (_state.globalPending)
            return;
        _state.globalPending = true;
        Qt.callLater(() => {
            rows._state.globalPending = false;
            for (let i = rows._trackers.length - 1; i >= 0; i--) {
                const t = rows._trackers[i];
                if (t?._st && !t._st.disposed && t.topCol)
                    t.recompute();
            }
        });
    }

    function onRowDestroyed(row: Item): void {
        if (!row)
            return;
        const id = row._rowsId ?? 0;
        const byIdTracker = id > 0 ? _trackerByRowId[id] : null;
        if (id > 0)
            delete _trackerByRowId[id];
        const t = (byIdTracker?._st && !byIdTracker._st.disposed && byIdTracker.topCol) ? byIdTracker : findTracker(topColumn(row, false));
        if (t?._st && !t._st.disposed && t.topCol)
            t.bump();
    }

    // The item that sits in the column: the row, or the Loader showing it
    function host(row: Item): Item {
        const p = row?.parent;
        return p && p.item === row ? p : row;
    }

    function isColumn(item: Item): bool {
        return item instanceof ColumnLayout || item instanceof Column;
    }

    function topColumn(item: Item, allowSelfColumn: bool): Item {
        if (!item)
            return null;
        let col = allowSelfColumn && isColumn(item) ? item : host(item)?.parent;
        if (!col)
            return null;
        while (isColumn(col) && isColumn(host(col)?.parent))
            col = host(col).parent;
        return col;
    }

    function trackerFor(topCol: Item): var {
        if (!topCol)
            return null;
        let t = findTracker(topCol);
        if (!t) {
            t = trackerComp.createObject(topCol, {
                topCol: topCol
            });
            _trackers.push(t);
            t.bump();
        }
        return t;
    }

    // Single-pass unified traversal of all visible visual items (rows and non-rows)
    // in a column hierarchy. Group rows are matched before reading/watching implicitHeight
    // so SectionHeader.card height changes never trigger feedback recomputations.
    function visit(k: Item, curGap: real, entries: var, bumpFn: var, unsubs: var): bool {
        if (!k)
            return false;
        watch(k, k.visibleChanged, bumpFn, unsubs);
        if (!k.visible)
            return false;
        if (k.isGroupRowChanged !== undefined)
            watch(k, k.isGroupRowChanged, bumpFn, unsubs);
        if (k.isGroupRow === true) {
            entries.push({
                item: k,
                isRow: true,
                gap: curGap
            });
            return true;
        }
        if (k.delegate !== undefined && k.model !== undefined)
            return false;
        if (k.sourceComponent !== undefined || k.source !== undefined) {
            watch(k, k.itemChanged, bumpFn, unsubs);
            return k.item ? visit(k.item, curGap, entries, bumpFn, unsubs) : false;
        }
        if (isColumn(k)) {
            watch(k, k.childrenChanged, bumpFn, unsubs);
            watch(k, k.spacingChanged, bumpFn, unsubs);
            const kids = k.children;
            const innerGap = k.spacing ?? 0;
            let sawAny = false;
            for (let i = 0; i < kids.length; i++) {
                if (visit(kids[i], sawAny ? innerGap : curGap, entries, bumpFn, unsubs))
                    sawAny = true;
            }
            return sawAny;
        }
        watch(k, k.implicitHeightChanged, bumpFn, unsubs);
        if (k.implicitHeight > 0 || k.height > 0) {
            entries.push({
                item: k,
                isRow: false,
                gap: curGap
            });
            return true;
        }
        return false;
    }

    function computeColumn(topCol: Item, bumpFn: var, unsubs: var): var {
        const byId = {};
        if (!topCol)
            return byId;
        watch(topCol, topCol.childrenChanged, bumpFn, unsubs);
        watch(topCol, topCol.spacingChanged, bumpFn, unsubs);
        const entries = [];
        const kids = topCol.children;
        const gap = topCol.spacing ?? 0;
        for (let i = 0; i < kids.length; i++)
            visit(kids[i], gap, entries, bumpFn, unsubs);
        for (let i = 0; i < entries.length; i++) {
            const cur = entries[i];
            const id = cur.item._rowsId ?? 0;
            if (!(id > 0))
                continue;
            const prev = i > 0 ? entries[i - 1] : null;
            const next = i + 1 < entries.length ? entries[i + 1] : null;
            byId[id] = {
                prevVisual: prev ? prev.item : null,
                nextVisual: next ? next.item : null,
                prevRow: prev && prev.isRow ? prev.item : null,
                nextRow: next && next.isRow ? next.item : null,
                gap: cur.gap
            };
        }
        return byId;
    }

    function entryFor(row: Item): var {
        const id = row?._rowsId ?? 0;
        if (!(id > 0))
            return null;
        const topCol = topColumn(row, false);
        if (!topCol)
            return null;
        const t = trackerFor(topCol);
        if (!t || !t._st || t._st.disposed)
            return null;
        _trackerByRowId[id] = t;
        return t.info ? (t.info[id] ?? null) : null;
    }

    // Nearest visible item next to `row` in its column chain (crossing nested columns)
    function adjacentVisual(row: Item, dir: int): Item {
        const e = entryFor(row);
        return e ? (dir < 0 ? e.prevVisual : e.nextVisual) : null;
    }

    function isAtTop(row: Item): bool {
        return !adjacentVisual(row, -1);
    }

    // The gap above a row (filled in when it continues a card): its column's spacing, or, for
    // the first row of a column inside another, the outer column's
    function gapAbove(row: Item): real {
        const e = entryFor(row);
        return e ? e.gap : (host(row)?.parent?.spacing ?? 0);
    }

    function isFirst(row: Item): bool {
        const e = entryFor(row);
        return !!row && (row.groupStart === true || !e?.prevRow);
    }

    function isLast(row: Item): bool {
        const e = entryFor(row);
        return !e?.nextRow || e.nextRow.groupStart === true;
    }
}
