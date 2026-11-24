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
    property color fillColour: Colours.tPalette.m3surfaceContainer
    readonly property int _rowsId: Rows.nextId()
    readonly property bool isGroupRow: !standalone
    property bool first: standalone ? true : Rows.isFirst(root)
    property bool last: standalone ? true : Rows.isLast(root)

    // The item that sits in the column: this, or the row this is the background of (ToggleRow)
    readonly property Item rowItem: parent && parent.isGroupRow === true ? parent : root
    // The column's gap above this row, filled when it continues a card
    readonly property real gap: Rows.gapAbove(rowItem)
    readonly property bool _bridgeAbove: !root.first && root.gap > 0

    Layout.topMargin: root.rowItem === root && root.groupStart && !Rows.isAtTop(root) ? Math.max(0, Tokens.spacing.largeIncreased - root.gap) : 0

    Component.onCompleted: Rows.bump(root.rowItem)
    Component.onDestruction: Rows.onRowDestroyed(root.rowItem)

    color: "transparent"
    topLeftRadius: first ? Tokens.rounding.extraLarge : 0
    topRightRadius: first ? Tokens.rounding.extraLarge : 0
    bottomLeftRadius: last ? Tokens.rounding.extraLarge : 0
    bottomRightRadius: last ? Tokens.rounding.extraLarge : 0

    // Clipped background extended past any flat seam edge so rounded-rect corner AA
    // never feathers flat edges between rows or creates a second seam against a bridge rect.
    Item {
        id: bgClip

        z: -1
        clip: true
        visible: root.fillColour.a > 0
        x: 0
        y: root._bridgeAbove ? -root.gap : 0
        width: root.width
        height: root.height + (root._bridgeAbove ? root.gap : 0)

        StyledRect {
            anchors.fill: parent
            anchors.topMargin: !root.first ? -2 : 0
            anchors.bottomMargin: !root.last ? -2 : 0
            color: root.fillColour
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
        }
    }
}
