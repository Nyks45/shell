pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// People's accounts on this computer and the groups worth offering
// (caelestia-system users); changes go through AccountsService / the root
// helper and call reload() after.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-system`
    // [{ name, uid, fullName, home, admin, groups, me }]
    property var users: []
    // [{ name, about }]
    property var groups: []
    readonly property var me: users.find(u => u.me) ?? null

    function reload(): void {
        proc.running = true;
    }

    function find(name: string): var {
        return users.find(u => u.name === name) ?? null;
    }

    // An account change through caelestia-system (secrets on stdin)
    function change(args: list<string>, what: string, done: var, input): void {
        Admin.exec([helper, ...args], what, (ok, out, cancelled) => {
            reload();
            if (typeof done === "function")
                done(ok, out, cancelled);
        }, input);
    }

    Process {
        id: proc

        command: [root.helper, "users"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.users = d.users ?? [];
                    root.groups = d.groups ?? [];
                } catch (e) {}
            }
        }
    }
}
