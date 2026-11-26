import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.nexus

ShellRoot {
    id: root

    function openEntry(entry: string): void {
        WindowFactory.create(null, { startEntry: entry ? JSON.parse(entry) : null });
    }

    Component.onCompleted: openEntry(Quickshell.env("CAELESTIA_NEXUS_ENTRY"))

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Connections {
        target: WindowFactory

        function onActiveWindowChanged(): void {
            if (!WindowFactory.activeWindow)
                Qt.quit();
        }

        function onWindowStateChanged(): void {
            console.log("NEXUS_WINDOW_STATE " + WindowFactory.windowState);
        }
    }

    IpcHandler {
        target: "nexusSoftware"
        function open(entry: string): void {
            root.openEntry(entry);
        }
        function navigate(action: string, index: int): void {
            WindowFactory.navigate(action, index);
        }
    }
}
