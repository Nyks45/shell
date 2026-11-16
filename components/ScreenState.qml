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

    // Last pointer position in the drawers window (scene coordinates) and when it was there:
    // the Drop motion grows a panel out of the point it was opened from
    property real pointerX: -1
    property real pointerY: -1
    property real pointerTime: 0

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
