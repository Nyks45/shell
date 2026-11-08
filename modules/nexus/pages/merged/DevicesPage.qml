pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.bluetooth

// Devices: Bluetooth and other devices, keyboard and mouse; one at a time (tabs).
// The parts are the former pages, embedded (PageBase.embedded).
PageBase {
    id: root

    title: Tr.tr("Devices")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PartTabs {
            parts: [bluetoothPart, inputPart]
        }

        TabPart {
            id: bluetoothPart

            title: Tr.tr("Bluetooth & devices")
            icon: "bluetooth"
            summary: Tr.tr("Bluetooth, paired devices, batteries")

            BluetoothPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }

        TabPart {
            id: inputPart

            title: Tr.tr("Keyboard & mouse")
            icon: "keyboard"
            summary: Tr.tr("Keyboard layouts, repeat, mouse and touchpad")

            InputPage {
                embedded: true
                nState: root.nState
                hostFlickable: root.flickable
            }
        }
    }
}
