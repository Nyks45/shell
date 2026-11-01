pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// What happens to a screenshot once taken (the area picker, the whole screen):
// copied to the clipboard, saved to a folder, a notification with Edit / Open /
// Show in folder, optionally a sound or the editor right away. The choices are
// the settings app's, kept in screenshot.json.
Singleton {
    id: root

    property var prefs: ({})
    readonly property bool copy: prefs.copy ?? true
    readonly property bool save: prefs.save ?? true
    readonly property bool showNotification: prefs.notify ?? true
    readonly property bool openEditor: prefs.edit ?? false
    readonly property bool sound: prefs.sound ?? false
    readonly property string editor: prefs.editor || "swappy"
    readonly property string defaultFolder: Quickshell.env("CAELESTIA_SCREENSHOTS_DIR") || `${Paths.pictures}/Screenshots`
    readonly property string folder: prefs.folder || defaultFolder

    function set(key: string, value: var): void {
        const next = Object.assign({}, prefs);
        next[key] = value;
        prefs = next;
        file.setText(JSON.stringify(next, null, 4) + "\n");
    }

    function editCommand(path: string): list<string> {
        // swappy and satty take the file with -f; others get it as the argument
        return editor === "swappy" || editor === "satty" ? [editor, "-f", path] : [editor, path];
    }

    // A captured image at `tmp`: copy, save, tell. `clipboardOnly` (the picker's
    // clipboard mode) only copies.
    function handle(tmp: string, clipboardOnly: bool): void {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const dest = clipboardOnly || !save ? tmp : `${folder}/Screenshot_${stamp}.png`;
        const steps = [];
        if (copy || clipboardOnly)
            steps.push(`wl-copy --type image/png < "$1"`);
        if (dest !== tmp)
            steps.push(`mkdir -p "$(dirname "$2")" && cp "$1" "$2" && rm -f "$1"`);
        // Copy-only shots stay for the notification's Edit, then go (an hour on)
        steps.push(`find /tmp -maxdepth 1 \\( -name 'caelestia-picker-*.png' -o -name 'caelestia-screenshot-*.png' \\) -mmin +60 -delete 2>/dev/null`);
        Quickshell.execDetached(["sh", "-c", steps.join("; "), "sh", tmp, dest]);
        if (sound)
            Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/camera-shutter.oga"]);
        if (openEditor && !clipboardOnly)
            Qt.callLater(() => Quickshell.execDetached(editCommand(dest)));
        if (showNotification)
            notifComp.createObject(root, {
                path: dest,
                saved: dest !== tmp,
                copied: copy || clipboardOnly
            });
    }

    // The whole focused screen
    function captureScreen(): void {
        const mon = Hypr.focusedMonitor?.name ?? "";
        screenProc.tmp = `/tmp/caelestia-screenshot-${Quickshell.processId}-${Date.now()}.png`;
        screenProc.command = ["grim", ...(mon ? ["-o", mon] : []), screenProc.tmp];
        screenProc.running = true;
    }

    Process {
        id: screenProc

        property string tmp

        onExited: code => {
            if (code === 0)
                root.handle(tmp, false);
        }
    }

    // One notification each: notify-send waits for the action picked on it
    Component {
        id: notifComp

        Process {
            id: notif

            required property string path
            required property bool saved
            required property bool copied

            running: true
            command: ["notify-send", "-a", "Screenshot", "-i", path, "-h", `string:image-path:${path}`, "--action=edit=Edit", ...(saved ? ["--action=open=Open", "--action=folder=Show in folder"] : []), saved ? (copied ? "Screenshot saved and copied" : "Screenshot saved") : "Screenshot copied", saved ? Paths.shortenHome(path) : "In the clipboard, ready to paste"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const action = text.trim();
                    if (action === "edit")
                        Quickshell.execDetached(root.editCommand(notif.path));
                    else if (action === "open")
                        Quickshell.execDetached(["xdg-open", notif.path]);
                    else if (action === "folder")
                        Quickshell.execDetached(["dbus-send", "--session", "--dest=org.freedesktop.FileManager1", "--type=method_call", "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1.ShowItems", `array:string:file://${notif.path}`, "string:"]);
                }
            }
            onExited: destroy()
        }
    }

    FileView {
        id: file

        path: `${Paths.config}/screenshot.json`
        printErrors: false
        blockAllReads: true
        onLoaded: {
            try {
                root.prefs = JSON.parse(text());
            } catch (e) {
                root.prefs = {};
            }
        }
    }
}
