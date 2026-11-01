pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

// Runs a command in the user's terminal, for settings that need sudo (it asks
// for the password there) or show their progress. The window stays open at
// the end until Enter is pressed.
Singleton {
    function run(script: string): void {
        Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "-e", "sh", "-c", `${script}; echo; read -p 'Press Enter to close' _`]);
    }

    // Shows what's about to happen and asks y/N first
    function confirm(what: string, script: string): void {
        const msg = what.replace(/'/g, "'\\''");
        run(`printf '%s\\n\\n' '${msg}'; printf 'Go ahead? [y/N] '; read a; case "$a" in [yY]*) ${script} ;; *) echo 'Nothing changed.' ;; esac`);
    }
}
