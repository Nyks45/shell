import QtQuick
import Quickshell
import qs.components
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.bar.popouts as BarPopouts

// The shell's islands on a screen: the top island (dashboard), the launcher, the volume and
// brightness island, the notification cards and the pill bar's menus
Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper

    anchors.fill: parent
    anchors.margins: borderThickness
    anchors.leftMargin: bar.implicitWidth

    // From this area's middle to the screen's (the bar on the left takes more than the border on
    // the right): the islands centred on the screen stay put while the bar comes and goes
    readonly property real screenCentreOffset: (borderThickness - bar.implicitWidth) / 2

    // The volume and brightness island, a gap from the right edge; this holds its hover zone
    // there (its own size plus the gap, the full height while it's closed too)
    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right

        implicitWidth: osd.implicitWidth > 0 ? osd.implicitWidth + osd.floatGap : 0
        implicitHeight: Math.max(osd.zoneHeight, osd.implicitHeight)

        Osd.Wrapper {
            id: osd

            screen: root.screen
            screenState: root.screenState

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        screenState: root.screenState
        osdPanel: osdWrapper

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        screenState: root.screenState
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        // (on the screen's middle, not this area's: it would move as the bar comes and goes)
        anchors.horizontalCenterOffset: root.screenCentreOffset
        // (the centred styles: in the middle of the screen)
        anchors.bottom: launcher.centred ? undefined : parent.bottom
        anchors.verticalCenter: launcher.centred ? parent.verticalCenter : undefined
    }

    Dashboard.Wrapper {
        id: dashboard

        screenState: root.screenState

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.screenCentreOffset
        anchors.top: parent.top
        anchors.topMargin: floatGap
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
    }
}
