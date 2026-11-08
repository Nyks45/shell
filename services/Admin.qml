pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// System changes from the settings, without a terminal: the root helper's
// named actions (caelestia-admin, through pkexec) and commands that ask
// polkit themselves (systemctl, udisks...). Either way the shell's own
// password prompt asks (Polkit), saying what the change is.
//
//   Admin.run("power-key", ["suspend"], qsTr("Set the power button"), (ok, out) => ...)
//   Admin.exec(["systemctl", "enable", "--now", "cups.socket"], what, done)
//
// done(ok, output, cancelled): cancelled = the password prompt was closed.
// A failure that isn't a cancel also shows a notification with its output.
Singleton {
    id: root

    readonly property string helper: `${Paths.libdir}/caelestia-admin`
    // Running jobs (Process objects with what, output); a plain array,
    // replaced on each change so bindings on it update
    property var jobs: []
    readonly property bool busy: jobs.length > 0

    function run(action: string, args: list<string>, what: string, done: var): void {
        exec(["pkexec", helper, action, ...args], what, done);
    }

    // input: written to the command's stdin (secrets: never on a command line)
    function exec(command: list<string>, what: string, done: var, input): void {
        const job = jobComp.createObject(root, {
            command,
            what,
            done: done ?? null,
            input: input ?? "",
            stdinEnabled: !!input
        });
        jobs = [...jobs, job];
        Polkit.context = what;
        job.running = true;
    }

    // Live output of the job doing `what` (for progress text), "" if none
    function outputOf(what: string): string {
        return jobs.find(j => j.what === what)?.output ?? "";
    }

    function finished(job: var, code: int): void {
        jobs = jobs.filter(j => j !== job);
        if (Polkit.context === job.what && !jobs.some(j => j.what === job.what))
            Polkit.context = "";

        const pk = job.command[0] === "pkexec";
        // pkexec (and the settings' own helpers): 126 = the prompt was
        // dismissed, 127 = not authorised
        const cancelled = code === 126;
        const ok = code === 0;
        const output = job.output.trim();
        if (!ok && !cancelled) {
            const msg = code === 127 && pk ? qsTr("Not allowed: the password wasn't accepted.") : output.split("\n").slice(-6).join("\n");
            Quickshell.execDetached(["notify-send", "-a", "Settings", "-i", "dialog-error", qsTr("Couldn't %1").arg(job.what.charAt(0).toLowerCase() + job.what.slice(1)), msg || qsTr("It stopped with error %1.").arg(code)]);
        }
        if (typeof job.done === "function")
            job.done(ok, output, cancelled);
        job.destroy();
    }

    Component {
        id: jobComp

        Process {
            id: proc

            property string what
            property var done
            property string output
            property string input

            environment: ({
                    LC_ALL: "C.UTF-8"
                })

            stdout: SplitParser {
                onRead: line => proc.output += line + "\n"
            }
            stderr: SplitParser {
                onRead: line => proc.output += line + "\n"
            }
            onStarted: {
                if (input) {
                    write(input + "\n");
                    input = "";
                    stdinEnabled = false;
                }
            }
            onExited: code => root.finished(proc, code)
        }
    }
}
