pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    property var activeWindow: null
    property var cachedWindow: null
    readonly property bool softwareProcess: Quickshell.env("CAELESTIA_NEXUS_SOFTWARE") === "1"
    readonly property string softwareConfig: Quickshell.shellPath("nexus-software.qml")
    property string softwareEntry
    property string softwareState: "{}"

    readonly property string windowState: {
        if (softwareWindow.running)
            return softwareState;
        const state = activeWindow?.visible ? activeWindow.nexusItem.nState : null;
        if (!state)
            return "{}";
        return JSON.stringify({
            page: state.currentPageIdx,
            path: Array.from(state.subPageIdxStack),
            historyIdx: state.historyIdx,
            history: state.history,
            canGoBack: state.canGoBack,
            canGoForward: state.canGoForward,
            searchOpen: state.searchOpen
        });
    }

    function openSoftware(entry: var): void {
        if (activeWindow)
            activeWindow.visible = false;
        const encoded = JSON.stringify(entry ?? null);
        if (softwareWindow.running)
            Quickshell.execDetached(["qs", "-p", softwareConfig, "ipc", "call", "nexusSoftware", "open", encoded]);
        else {
            softwareEntry = encoded;
            softwareWindow.running = true;
        }
    }

    function navigate(action: string, index: int): void {
        if (softwareWindow.running) {
            Quickshell.execDetached(["qs", "-p", softwareConfig, "ipc", "call", "nexusSoftware", "navigate", action, String(index)]);
            return;
        }
        const state = activeWindow?.nexusItem.nState;
        if (!state)
            return;
        switch (action) {
        case "back": state.back(); break;
        case "forward": state.forward(); break;
        case "up": state.up(); break;
        case "openSub": state.openSubPage(index); break;
        case "closeSub": state.closeSubPage(); break;
        }
    }

    Process {
        id: softwareWindow

        command: ["qs", "-n", "-p", root.softwareConfig]
        environment: ({
            QT_QUICK_BACKEND: "software",
            CAELESTIA_NEXUS_SOFTWARE: "1",
            CAELESTIA_NEXUS_ENTRY: root.softwareEntry
        })
        stdout: SplitParser {
            onRead: line => {
                const prefix = "NEXUS_WINDOW_STATE ";
                const index = line.indexOf(prefix);
                if (index >= 0)
                    root.softwareState = line.slice(index + prefix.length);
            }
        }
        onExited: root.softwareState = "{}"
    }

    function focusExisting(): void {
        if (!activeWindow)
            return;
        activeWindow.visible = true;
        // The shell's own window (Quickshell's class), not any app's "Settings"
        const titleStr = Tr.tr("Settings");
        const tl = Hypr.toplevels.values.find(t => (t.lastIpcObject?.title ?? t.title) === titleStr && /quickshell/i.test(t.lastIpcObject?.class ?? ""));
        if (!tl)
            return; // just shown: it gets focus as it maps
        const sel = `address:0x${tl.address}`;
        if (Hypr.usingLua)
            Hypr.extras.message(`eval local hf = hl.plugin and hl.plugin.hyprflow; if hf and hf.activate then hf.activate("${sel}") else hl.dispatch(hl.dsp.focus({ window = "${sel}" })) end`);
        else
            Hypr.dispatch(`focuswindow ${sel}`);
    }

    function create(parent: Item, props: var): void {
        if (!softwareProcess && !LiveWallpaper.setting("browserHardwareAcceleration", true)) {
            openSoftware(props?.startEntry);
            return;
        }
        if (softwareWindow.running)
            softwareWindow.running = false;
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
        // The tab goes with the entry (the window's NexusState sets it for itself)
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
