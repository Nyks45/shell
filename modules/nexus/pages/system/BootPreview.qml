pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The boot menu (rEFInd) as it shows on the screen, drawn from the draft:
// background, the big entry icons with the selection behind the chosen one,
// the small tool icons, names and hints unless hidden. Sizes are the real
// pixel sizes scaled from the screen to the preview. A click on an entry
// picks it (entryClicked).
Item {
    id: root

    // The draft (BootPage): { background, selectionBig, selectionSmall, bigIconSize,
    // smallIconSize, hideui, tools: [{ tool, iconFile }], entries: [{ name, iconFile, hidden }], selected }
    required property var draft
    // The screen the menu draws on (its real size)
    property real screenWidth: 2560
    property real screenHeight: 1440

    readonly property real scale: width / screenWidth
    readonly property var shown: (draft?.entries ?? []).filter(e => !e.hidden)
    readonly property var hide: draft?.hideui ?? []

    signal entryClicked(name: string)

    implicitHeight: width * screenHeight / screenWidth
    clip: true

    function file(path: string): string {
        return path ? (path.startsWith("file://") ? path : `file://${path}`) : "";
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Image {
        anchors.fill: parent
        visible: !root.hide.includes("banner")
        source: root.file(root.draft?.background ?? "")
        fillMode: Image.Stretch
        asynchronous: true
        cache: false
        sourceSize.width: 1280
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24 * root.scale

        // Big icons: the boot entries
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8 * root.scale

            Repeater {
                model: root.shown

                Item {
                    id: tile

                    required property var modelData

                    readonly property real icon: (root.draft?.bigIconSize ?? 128) * root.scale
                    readonly property bool selected: (root.draft?.selected || root.shown[0]?.name) === modelData.name

                    width: icon * 1.125
                    height: width

                    Image {
                        anchors.fill: parent
                        visible: tile.selected
                        source: root.file(root.draft?.selectionBig ?? "")
                        fillMode: Image.Stretch
                        asynchronous: true
                    }

                    Image {
                        anchors.centerIn: parent
                        width: tile.icon
                        height: tile.icon
                        source: root.file(tile.modelData.iconFile ?? "")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        sourceSize.width: 256
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.entryClicked(tile.modelData.name)
                    }
                }
            }
        }

        // Small icons: the tools
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: (root.draft?.tools ?? []).length > 0
            spacing: 8 * root.scale

            Repeater {
                model: root.draft?.tools ?? []

                Item {
                    required property var modelData

                    readonly property real icon: (root.draft?.smallIconSize ?? 48) * root.scale

                    width: icon * 1.125
                    height: width

                    Image {
                        anchors.centerIn: parent
                        width: parent.icon
                        height: parent.icon
                        source: root.file(parent.modelData.iconFile ?? "")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
            }
        }

        // The chosen entry's name (unless "label" is hidden)
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.hide.includes("label") && root.shown.length > 0
            text: Tr.tr("Boot %1").arg(root.draft?.selected || root.shown[0]?.name || "")
            color: "white"
            font.pixelSize: Math.max(7, 28 * root.scale)
        }
    }

    // Keyboard hints at the bottom (unless hidden)
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24 * root.scale
        visible: !root.hide.includes("hints")
        horizontalAlignment: Text.AlignHCenter
        text: Tr.tr("Use arrow keys to move cursor; Enter to boot;\nInsert, Tab, or F2 for more options; Esc or Backspace to refresh")
        color: "white"
        font.pixelSize: Math.max(6, 22 * root.scale)
    }
}
