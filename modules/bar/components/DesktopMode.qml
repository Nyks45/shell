import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Toggles hyprflow's desktop mode (floating Windows-like desktop) and shows
// whether it's on: a highlighted monitor when on, columns (the scrolling
// layout) when off.
Item {
    id: root

    readonly property bool active: Hypr.desktopMode

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: implicitWidth

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.6

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    StateLayer {
        radius: Tokens.rounding.full
        onClicked: Hypr.toggleDesktopMode()
    }

    MaterialIcon {
        anchors.centerIn: parent

        animate: true
        text: root.active ? "desktop_windows" : "view_week"
        fill: root.active ? 1 : 0
        color: root.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.medium

        Behavior on color {
            CAnim {}
        }
    }
}
