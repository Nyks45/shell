import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A row's background, rounded at the ends of its group of rows: where it
// sits among the visible rows of its column (Rows) unless set.
StyledRect {
    id: root

    // Starts a new group even right after another row
    property bool groupStart
    readonly property bool isGroupRow: true
    property bool first: Rows.isFirst(root)
    property bool last: Rows.isLast(root)

    Component.onCompleted: Rows.bump()
    Component.onDestruction: Rows.bump()

    color: Colours.tPalette.m3surfaceContainer
    topLeftRadius: first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomLeftRadius: last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
}
