import QtQuick
import Quickshell
import qs.nebula.widgets.desktop

// Nebula's desktop widgets (github.com/LilaccFlowerr/Nebula, AGPL-3.0; see NEBULA.md): the
// widgets layer and its right-click menus, on every screen.
Scope {
    WidgetsWindow {}

    Variants {
        model: Quickshell.screens

        WidgetMenu {}
    }

    Variants {
        model: Quickshell.screens

        DesktopMenu {}
    }
}
