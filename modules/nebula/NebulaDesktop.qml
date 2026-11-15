import QtQuick
import Quickshell
import qs.nebula.widgets.desktop

// Nebula's desktop widgets (github.com/LilaccFlowerr/Nebula, AGPL-3.0; see NEBULA.md): the
// widgets layer, its right-click menus and the widgets corner, on every screen.
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

    Variants {
        model: Quickshell.screens

        WidgetsCorner {
            required property ShellScreen modelData

            screen: modelData
        }
    }
}
