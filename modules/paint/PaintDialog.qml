import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A modal card over the whole window. Content goes in as children; `buttons` holds the row at the bottom.
Item {
    id: root

    property string title
    property string icon
    property bool open
    property real cardWidth: 420
    default property alias content: body.data
    property alias buttons: buttonRow.data

    // where keyboard focus goes when the dialog closes: a function giving the item (another open dialog, or the canvas)
    property var focusReturn: null

    signal dismissed

    onOpenChanged: {
        if (open)
            Qt.callLater(() => {
                if (root.open && !root.activeFocusInside())
                    root.forceActiveFocus();
            });
        else if (focusReturn)
            Qt.callLater(() => root.focusReturn()?.forceActiveFocus());
    }

    function activeFocusInside(): bool {
        for (let it = Window.activeFocusItem; it; it = it.parent)
            if (it === root)
                return true;
        return false;
    }

    anchors.fill: parent
    z: 900
    visible: opacity > 0
    opacity: open ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Keys.onEscapePressed: {
        root.open = false;
        root.dismissed();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("black", 0.4)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
            onClicked: {
                root.open = false;
                root.dismissed();
            }
        }
    }

    StyledRect {
        id: card

        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - 32)
        implicitHeight: col.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh
        scale: root.open ? 1 : 0.95

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            id: col

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    visible: root.icon !== ""
                    text: root.icon
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font: Tokens.font.title.medium
                    wrapMode: Text.Wrap
                }
            }

            ColumnLayout {
                id: body

                Layout.fillWidth: true
                spacing: Tokens.spacing.small
            }

            RowLayout {
                id: buttonRow

                Layout.alignment: Qt.AlignRight
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.small
            }
        }
    }
}
