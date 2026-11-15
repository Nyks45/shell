pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.nebula.services
import qs.nebula.theme

// Nebula's own settings pages for its parts (github.com/LilaccFlowerr/Nebula, AGPL-3.0), shown
// inside the shell's settings app with their own look. Nebula moves between its pages with
// navigate(target); SettingsNav.sub keeps the current one ("" = the widgets overview).
PageBase {
    id: root

    readonly property string sub: SettingsNav.sub
    readonly property string subKey: sub.split(":")[0]
    readonly property string subArg: sub.split(":")[1] ?? ""
    readonly property var current: subKey === "widget" ? {
            title: Widgets.types[Widgets.get(subArg)?.type]?.title ?? Tr.tr("Widget"),
            source: "../../../../nebula/widgets/settings/pages/desktop/WidgetPage.qml"
        } : subKey === "newwidget" ? {
            title: Tr.tr("Add a widget"),
            source: "../../../../nebula/widgets/settings/pages/desktop/NewWidgetPage.qml"
        } : subKey === "images" ? {
            title: Tr.tr("Choose an image"),
            source: "../../../../nebula/widgets/settings/pages/ImagePickerPage.qml"
        } : {
            title: Tr.tr("Desktop widgets"),
            source: "../../../../nebula/widgets/settings/pages/DesktopPage.qml"
        }

    title: current.title
    isSubPage: true

    // The header's back arrow (and the mouse's back button) first step back within Nebula's pages
    Component.onCompleted: nState.backHandler = () => {
        if (SettingsNav.sub === "")
            return false;
        SettingsNav.sub = "";
        return true;
    }
    Component.onDestruction: SettingsNav.sub = ""

    // Each of Nebula's pages starts at the top (going back from a scrolled widget page kept
    // the overview scrolled, cut off at the top)
    onSubChanged: if (flickable)
        flickable.contentY = 0

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Theme.spacing.md

        Loader {
            id: loader

            Layout.fillWidth: true
            source: Qt.resolvedUrl(root.current.source)
            onLoaded: {
                if (item.arg !== undefined)
                    item.arg = Qt.binding(() => root.subArg);
                Qt.callLater(() => {
                    if (root.flickable)
                        root.flickable.contentY = 0;
                });
            }
        }

        Connections {
            function onNavigate(target: string): void {
                SettingsNav.sub = target;
            }

            target: loader.item
            ignoreUnknownSignals: true
        }
    }
}
