pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.components.misc

// The task manager (Ctrl+Shift+Esc, Ctrl+Alt+Delete): apps and processes, performance and
// services, drawn above everything (fullscreen apps too) so a hung app can always be ended.
// Nothing of it exists while it's closed: the window and its readings load on opening.
Scope {
    id: root

    property bool shown

    LazyLoader {
        active: root.shown

        TaskWindow {
            onCloseRequested: root.shown = false
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "taskmanager"
        description: "Task manager"
        onPressed: root.shown = !root.shown
    }

    // `caelestia shell taskmanager toggle` (or open / close)
    IpcHandler {
        function toggle(): void {
            root.shown = !root.shown;
        }

        function open(): void {
            root.shown = true;
        }

        function close(): void {
            root.shown = false;
        }

        target: "taskmanager"
    }
}
