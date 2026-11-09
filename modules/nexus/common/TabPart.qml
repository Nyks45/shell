pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// One sub-setting of a page, shown once chosen (PartTabs). Made the first
// time it shows. The search opens the part that has the row (PageBase).
ColumnLayout {
    id: root

    property string title
    // Its former page id (a page opened at it shows this tab: PageRegistry.pendingTab)
    property string key
    property string icon
    // What it has (its row before one is chosen)
    property string summary
    property bool open
    default property Component content
    readonly property bool isFold: true
    property bool built

    onOpenChanged: if (open)
        built = true

    Layout.fillWidth: true
    visible: open
    spacing: 0

    Loader {
        Layout.fillWidth: true
        active: root.built
        sourceComponent: root.content
    }
}
