pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // (in the pill: smaller than the apps' icons, and single-coloured)
    implicitWidth: Tokens.font.body.small.pointSize * (Config.bar.pill ? 1.45 : 2)
    implicitHeight: Tokens.font.body.small.pointSize * (Config.bar.pill ? 1.45 : 2)

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Config.bar.pill ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour || Config.bar.pill
    }
}
