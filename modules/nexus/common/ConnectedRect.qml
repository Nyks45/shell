import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A row's background. Rows next to each other in a column (with their section's header) form
// one card: rounded at its top and bottom only, square where rows meet, and the column's gap
// between them filled in, so the card reads as one piece (where it sits among the visible rows
// of its column: Rows, unless set).
StyledRect {
    id: root

    // Starts a new group even right after another row
    property bool groupStart
    property bool standalone
    readonly property int _rowsId: Rows.nextId()
    readonly property bool isGroupRow: !standalone
    property bool first: standalone ? true : Rows.isFirst(root)
    property bool last: standalone ? true : Rows.isLast(root)

    // The item that sits in the column: this, or the row this is the background of (ToggleRow)
    readonly property Item rowItem: parent && parent.isGroupRow === true ? parent : root
    // The column's gap above this row, filled when it continues a card
    readonly property real gap: Rows.gapAbove(rowItem)

    Layout.topMargin: root.rowItem === root && root.groupStart && !Rows.isAtTop(root) ? Math.max(0, Tokens.spacing.largeIncreased - root.gap) : 0

    Component.onCompleted: Rows.bump(root.rowItem)
    Component.onDestruction: Rows.onRowDestroyed(root.rowItem)

    color: Colours.tPalette.m3surfaceContainer
    topLeftRadius: first ? Tokens.rounding.extraLarge : 0
    topRightRadius: first ? Tokens.rounding.extraLarge : 0
    bottomLeftRadius: last ? Tokens.rounding.extraLarge : 0
    bottomRightRadius: last ? Tokens.rounding.extraLarge : 0

    Rectangle {
        visible: !root.first && root.gap > 0
        y: -root.gap
        width: root.width
        height: root.gap
        color: root.color
    }
}
