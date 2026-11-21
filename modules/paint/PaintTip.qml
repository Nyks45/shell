import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A tooltip shown above everything in the window, next to `target`
StyledRect {
    id: root

    property Item target
    property string text
    property bool shown
    property int side: PaintTip.Below

    enum Side {
        Below,
        Right,
        Above
    }

    parent: target?.Window.window?.contentItem ?? null
    z: 1000
    visible: opacity > 0
    opacity: shown && text !== "" ? 1 : 0
    implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: label.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3inverseSurface

    x: {
        if (!target || !parent)
            return 0;
        const p = target.mapToItem(parent, 0, 0);
        const want = side === PaintTip.Right ? p.x + target.width + 8 : p.x + (target.width - width) / 2;
        return Math.max(4, Math.min(parent.width - width - 4, want));
    }
    y: {
        if (!target || !parent)
            return 0;
        const p = target.mapToItem(parent, 0, 0);
        if (side === PaintTip.Right)
            return Math.max(4, Math.min(parent.height - height - 4, p.y + (target.height - height) / 2));
        if (side === PaintTip.Above || p.y + target.height + height + 12 > parent.height)
            return p.y - height - 6;
        return p.y + target.height + 6;
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Colours.palette.m3inverseOnSurface
        font: Tokens.font.label.medium
    }
}
