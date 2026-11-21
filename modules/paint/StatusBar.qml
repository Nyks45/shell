import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "Tools.js" as Tools

// Picture size, pointer position, selection size, a hint for the tool and the zoom
Item {
    id: root

    required property var win
    readonly property var p: win.hovering && win.ready ? win.toImage(win.hoverPos.x, win.hoverPos.y) : null
    readonly property bool inside: !!p && p.x >= 0 && p.y >= 0 && p.x < win.doc.W && p.y < win.doc.H
    readonly property var sizeShown: win.drag === "area" || win.area ? win.area : win.band ?? win.selBox

    readonly property bool hintCut: hint.truncated

    implicitHeight: 26

    component Cell: RowLayout {
        property alias icon: ic.text
        property alias text: tx.text

        spacing: 4

        MaterialIcon {
            id: ic

            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
        }
        StyledText {
            id: tx

            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        spacing: Tokens.spacing.large

        Cell {
            icon: "photo_size_select_large"
            text: `${Math.round(root.win.doc.W)} × ${Math.round(root.win.doc.H)} px`
        }

        Cell {
            Layout.preferredWidth: 110
            icon: "my_location"
            text: root.inside ? `${Math.floor(root.p.x)}, ${Math.floor(root.p.y)}` : "—"
        }

        Cell {
            Layout.preferredWidth: 120
            visible: !!root.sizeShown && root.sizeShown.w > 0
            icon: "select"
            text: root.sizeShown ? `${Math.round(root.sizeShown.w)} × ${Math.round(root.sizeShown.h)}` : ""
        }

        StyledText {
            id: hint

            Layout.fillWidth: true
            text: Tr.tr(Tools.hints[root.win.spaceHeld ? "hand" : root.win.tool] ?? "")
            elide: Text.ElideRight
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }

        StyledText {
            text: root.win.fitMode ? Tr.tr("Fit (%1%)").arg(Math.round(root.win.zoom * 100)) : `${Math.round(root.win.zoom * 100)}%`
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
