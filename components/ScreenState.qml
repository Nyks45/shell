import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    // The power menu is the bar's popout on this screen (it has a power button)
    property bool sessionAtBar
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar

    // Dashboard state
    property int dashboardTab
    // Opened at one page from the island's buttons: that page alone, no tabs
    property bool dashboardSolo
    property date dashboardDate: new Date()
}
