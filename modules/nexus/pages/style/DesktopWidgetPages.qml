pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.modules.nexus.common
import qs.widgets.services
import qs.widgets.theme

// The desktop widgets' own settings pages (based on LilaccFlowerr's Nebula, AGPL-3.0), shown
// inside the shell's settings app with their own look. The widgets move between their pages with
// navigate(target); SettingsNav.sub keeps the current one ("" = the widgets overview).
PageBase {
    id: root

    readonly property string sub: SettingsNav.sub
    readonly property string subKey: sub.split(":")[0]
    readonly property string subArg: sub.split(":")[1] ?? ""
    readonly property var current: subKey === "widget" ? {
            title: Widgets.types[Widgets.get(subArg)?.type]?.title ?? Tr.tr("Widget"),
            source: "../../../../widgets/settings/pages/desktop/WidgetPage.qml"
        } : subKey === "newwidget" ? {
            title: Tr.tr("Add a widget"),
            source: "../../../../widgets/settings/pages/desktop/NewWidgetPage.qml"
        } : subKey === "images" ? {
            title: Tr.tr("Choose an image"),
            source: "../../../../widgets/settings/pages/ImagePickerPage.qml"
        } : {
            title: Tr.tr("Desktop widgets"),
            source: "../../../../widgets/settings/pages/DesktopPage.qml"
        }

    title: current.title
    isSubPage: true

    // The header's back arrow (and the mouse's back button) first step back within the widgets' pages
    Component.onCompleted: nState.backHandler = () => {
        if (SettingsNav.sub === "")
            return false;
        SettingsNav.sub = "";
        return true;
    }
    Component.onDestruction: SettingsNav.sub = ""

    readonly property int animMovement: Tokens.padding.extraExtraLarge * 2

    onSubChanged: {
        if (sub === loader.shownSub)
            return;
        // Deeper ("" -> a widget, a widget -> its images) slides in from the right, back from the left
        pageAnim.dir = sub === "" || (loader.shownSub.startsWith("images") && sub.startsWith("widget")) ? -1 : 1;
        pageAnim.restart();
    }


    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Theme.spacing.md

        SequentialAnimation {
            id: pageAnim

            property int dir: 1

            Anim {
                target: loader
                property: "opacity"
                to: 0
                type: Anim.DefaultEffects
            }
            ScriptAction {
                script: {
                    loader.slide = pageAnim.dir * root.animMovement;
                    loader.shownSub = root.sub;
                    loader.shown = Qt.resolvedUrl(root.current.source);
                    // Each of the widgets' pages starts at the top
                    if (root.flickable)
                        root.flickable.contentY = 0;
                }
            }
            PauseAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
            ParallelAnimation {
                Anim {
                    target: loader
                    property: "opacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
                Anim {
                    target: loader
                    property: "slide"
                    to: 0
                    type: Anim.FastSpatial
                }
            }
        }

        Loader {
            id: loader

            // Moving between the widgets' pages: like the settings' own pages (StackPage): the old one
            // fades out, the new one fades in sliding from the side it comes from
            property url shown: Qt.resolvedUrl(root.current.source)
            property string shownSub: root.sub
            property real slide: 0

            Layout.fillWidth: true
            Layout.leftMargin: slide
            Layout.rightMargin: -slide
            source: shown
            onLoaded: {
                if (item.arg !== undefined)
                    // the page shown (not the one coming), so it keeps its data while fading out
                    item.arg = Qt.binding(() => loader.shownSub.split(":")[1] ?? "");
                Qt.callLater(() => {
                    // the page may be gone by then (settings closed)
                    if (root?.flickable)
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
