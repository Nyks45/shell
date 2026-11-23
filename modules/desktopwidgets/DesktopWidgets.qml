import QtQuick
import Quickshell
import qs.widgets.desktop

// The desktop widgets (based on LilaccFlowerr's Nebula, AGPL-3.0; see widgets/README.md): the
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
