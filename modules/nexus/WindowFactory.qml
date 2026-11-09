pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    function create(parent: Item, props: var): void {
        nexusComp.createObject(parent ?? dummy, props);
    }

    // Opened at a page (PageRegistry id) and sub-page path, e.g. ("wallpaper", [4])
    function createAt(pageId: string, path: var): void {
        const page = PageRegistry.find(pageId);
        PageRegistry.pendingTab = PageRegistry.aliases[pageId] ? pageId : "";
        PageRegistry.pendingTabAt = Date.now();
        create(null, page < 0 ? {} : {
            startEntry: {
                page,
                path: path ?? []
            }
        });
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            property var startEntry: null

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.destroy()
                Component.onCompleted: if (win.startEntry)
                    nState.goTo(win.startEntry)
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
