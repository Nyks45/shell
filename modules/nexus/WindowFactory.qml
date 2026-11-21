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

    property var activeWindow: null
    property var cachedWindow: null

    function focusExisting(): void {
        if (!activeWindow)
            return;
        activeWindow.visible = true;
        const titleStr = Tr.tr("Settings");
        const tl = Hypr.toplevels.values.find(t => (t.lastIpcObject?.title ?? t.title) === titleStr);
        if (tl && Hypr.usingLua) {
            const sel = `address:0x${tl.address}`;
            Hypr.extras.message(`eval local hf = hl.plugin and hl.plugin.hyprflow; if hf and hf.activate then hf.activate("${sel}") else hl.dispatch(hl.dsp.focus({ window = "${sel}" })) end`);
        } else {
            Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.focus({ window = "title:^Settings$" })' : 'focuswindow title:^Settings$');
        }
    }

    function create(parent: Item, props: var): void {
        if (activeWindow && activeWindow.visible) {
            if (props?.startEntry)
                activeWindow.nexusItem.nState.goTo(props.startEntry);
            focusExisting();
            return;
        }
        if (cachedWindow) {
            cachedWindow.visible = false;
            activeWindow = cachedWindow;
            cachedWindow.nexusItem.activate(props?.startEntry ?? null);
            cachedWindow.visible = true;
            return;
        }
        cachedWindow = nexusComp.createObject(parent ?? dummy, props ?? {});
        activeWindow = cachedWindow;
    }

    // Opened at a page (PageRegistry id) and sub-page path, e.g. ("wallpaper", [4])
    function createAt(pageId: string, path: var): void {
        const page = PageRegistry.find(pageId);
        const tab = PageRegistry.aliases[pageId] ? pageId : "";
        PageRegistry.pendingTab = tab;
        PageRegistry.pendingTabAt = Date.now();
        create(null, page < 0 ? {} : {
            startEntry: {
                page,
                path: path ?? [],
                tab
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
            readonly property alias nexusItem: nexus

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onClosed: visible = false

            onVisibleChanged: {
                if (!visible) {
                    if (root.activeWindow === win)
                        root.activeWindow = null;
                    nexus.deactivate();
                }
            }

            Component.onDestruction: {
                if (root.activeWindow === win)
                    root.activeWindow = null;
                if (root.cachedWindow === win)
                    root.cachedWindow = null;
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen?.name ?? ""
            contentItem.Tokens.screen: screen?.name ?? ""

            title: Tr.tr("Settings")

            Nexus {
                id: nexus

                anchors.fill: parent
                initialEntry: win.startEntry
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.visible = false
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
