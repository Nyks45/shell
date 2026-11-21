import QtQuick
import qs.components.controls

// An icon button with a tooltip (`tip`, optionally with its shortcut)
IconButton {
    id: root

    property string tip
    property string keys
    property int tipSide: PaintTip.Below

    objectName: `btn:${icon}`
    type: IconButton.Text

    Timer {
        id: delay

        interval: 450
        running: root.hovered && root.tip !== ""
    }

    PaintTip {
        target: root
        side: root.tipSide
        text: root.keys !== "" ? `${root.tip}  (${root.keys})` : root.tip
        shown: root.hovered && !delay.running && !root.pressed
    }
}
