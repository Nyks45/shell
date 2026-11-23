import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool osdExpanded
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
    // The island shows a page to work in (the settings): it stays open when the pointer leaves,
    // takes the keyboard, and closes on Escape or a click outside
    property bool dashboardSticky
    // A page of the island asked for (e.g. "settings" from the quick settings' lists), and the
    // settings page to show there (a page id, PageRegistry)
    property string dashboardRequest
    property string dashboardSettingsPage
    property string dashboardQuickDetail
    property date dashboardDate: new Date()
}
