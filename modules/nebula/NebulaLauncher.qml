pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.nebula.services as Neb
import qs.nebula.widgets.launcher

// Launcher style "Nebula" (Wallpaper & style > Nebula): Nebula's Clover ring
// (github.com/LilaccFlowerr/Nebula, AGPL-3.0; see NEBULA.md) in place of the drawer list.
// Every way the shell opens its launcher (Super, the hot corner, `caelestia shell drawers toggle
// launcher`, the bar's logo, a drag up from the bottom edge) sets the screen's launcher state;
// that state and the ring's open state follow each other here.
Scope {
    id: root

    LauncherWindow {}

    Variants {
        model: Screens.screens

        Connections {
            id: link

            required property ShellScreen modelData

            function onLauncherChanged(): void {
                const s = target;
                if (s.launcher && !GlobalConfig.launcher.enabled) {
                    s.launcher = false;
                } else if (s.launcher) {
                    if (!Neb.GlobalStates.launcherOpen || Neb.GlobalStates.screen !== modelData.name)
                        Neb.Launcher.open(modelData.name);
                } else if (Neb.GlobalStates.launcherOpen && Neb.GlobalStates.screen === modelData.name) {
                    Neb.Launcher.close();
                }
            }

            target: ShellState.forScreen(modelData)
        }
    }

    Connections {
        function onLauncherOpenChanged(): void {
            root.syncStates();
        }
        function onScreenChanged(): void {
            root.syncStates();
        }

        target: Neb.GlobalStates
    }

    // The ring closed itself (Escape, a click outside, an app started, a workspace change) or
    // opened from its own IPC: the screens' launcher states follow
    function syncStates(): void {
        for (const screen of Screens.screens) {
            const s = ShellState.forScreen(screen);
            const open = Neb.GlobalStates.launcherOpen && Neb.GlobalStates.screen === screen.name;
            if (s && s.launcher !== open)
                s.launcher = open;
        }
    }

    Component.onDestruction: {
        Neb.Launcher.close();
        for (const screen of Screens.screens) {
            const s = ShellState.forScreen(screen);
            if (s)
                s.launcher = false;
        }
    }
}
