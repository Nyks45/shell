import QtQuick

// Workaround for Qt 6 QQuickItemView bug: delegates created or cached outside
// the viewport stay culled (QQuickItemPrivate::culled) when view transitions
// animate them into view, because QQuickItemView::showVisibleItems() does not
// re-run on transition progress or completion unless viewportMoved() fires.
QtObject {
    id: root

    required property var view

    readonly property bool active: Boolean(view) && (Boolean(view.move?.running)
        || Boolean(view.displaced?.running)
        || Boolean(view.addDisplaced?.running)
        || Boolean(view.removeDisplaced?.running)
        || Boolean(view.moveDisplaced?.running)
        || Boolean(view.add?.running)
        || Boolean(view.populate?.running))

    function refresh(): void {
        const v = root.view;
        if (!v || v.moving || v.dragging || v.flicking || v.count === 0)
            return;
        const horizontal = (v.orientation !== undefined && v.orientation === ListView.Horizontal)
            || (v.flow !== undefined && v.flow === GridView.FlowTopToBottom);
        if (horizontal) {
            const cx = v.contentX;
            v.contentX = cx + 0.001;
            v.contentX = cx;
        } else {
            const cy = v.contentY;
            v.contentY = cy + 0.001;
            v.contentY = cy;
        }
    }

    onActiveChanged: {
        if (!active)
            Qt.callLater(refresh);
    }

    readonly property FrameAnimation _frame: FrameAnimation {
        running: root.active
        onTriggered: root.refresh()
    }
}
