pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: adapter?.enabled ?? false
    readonly property var upowerDevices: {
        const btNames = new Set(Bluetooth.devices.values.filter(b => b.connected && b.batteryAvailable && b.name).map(b => b.name.trim().toLowerCase()));
        return UPower.devices.values.filter(d => d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Ups && d.nativePath !== "" && !btNames.has((d.model ?? "").trim().toLowerCase()));
    }

    title: Tr.tr("Bluetooth & devices")

    onVisibleChanged: if (!visible && adapter?.discoverable)
        adapter.discoverable = false
    Component.onDestruction: if (adapter?.discoverable)
        adapter.discoverable = false

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            text: Tr.tr("Bluetooth")
            subtext: !root.adapter ? Tr.tr("No Bluetooth adapter found") : ""
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            disabled: !root.adapter
            checked: root.btEnabled
            onToggled: {
                if (root.adapter)
                    root.adapter.enabled = checked;
            }
        }

        ItemList {
            id: savedList

            showList: root.btEnabled
            placeholderIcon: root.btEnabled ? "devices_other" : "bluetooth_disabled"
            placeholderText: !root.adapter ? Tr.tr("No Bluetooth adapter found") : root.btEnabled ? Tr.tr("No saved devices") : Tr.tr("Bluetooth disabled")

            model: ScriptModel {
                values: Bluetooth.devices.values.filter(d => d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
            }

            delegate: StyledRect {
                id: device

                required property BluetoothDevice modelData
                readonly property bool connected: modelData && modelData.state === BluetoothDeviceState.Connected
                readonly property bool loading: modelData && (modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting)
                property real textOpacity: loading ? 0.5 : 1

                anchors.left: savedList.list.contentItem.left
                anchors.right: savedList.list.contentItem.right
                implicitHeight: deviceLayout.implicitHeight + deviceLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                color: "transparent"

                Behavior on textOpacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                StateLayer {
                    disabled: device.loading
                    onClicked: {
                        if (!device.modelData || device.loading)
                            return;
                        root.nState.selectedBtDevice = device.modelData;
                        root.nState.openSubPage(1); // Per device info page
                    }
                }

                RowLayout {
                    id: deviceLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        id: deviceIcon

                        text: Icons.getBluetoothIcon(device.modelData?.icon ?? "")
                        color: device.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        fill: device.connected ? 1 : 0
                        opacity: device.textOpacity

                        Behavior on fill {
                            Anim {}
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: device.textOpacity

                        StyledText {
                            Layout.fillWidth: true
                            text: device.modelData?.name ?? Tr.trCtx("Unknown", "unknown bluetooth device")
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!device.connected)
                                    return Tr.trCtx("Saved", "bluetooth device state");
                                if (device.modelData?.batteryAvailable)
                                    // TRANSLATORS: %1 = battery level, already formatted as a percentage
                                    return Tr.trCtx("Connected • %1", "bluetooth device state with battery").arg(Strings.percentOne(device.modelData.battery));
                                return Tr.trCtx("Connected", "bluetooth device state");
                            }
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    AnimLoader {
                        Layout.alignment: Qt.AlignVCenter
                        sourceComp: device.loading ? loadingComp : connectBtnComp

                        Component {
                            id: connectBtnComp

                            TextButton {
                                text: device.connected ? Tr.trCtx("Disconnect", "button") : Tr.trCtx("Connect", "button")
                                type: TextButton.Tonal
                                onClicked: {
                                    if (device.modelData)
                                        device.modelData.connected = !device.connected;
                                }
                            }
                        }

                        Component {
                            id: loadingComp

                            LoadingIndicator {
                                implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                            }
                        }
                    }

                    MaterialIcon {
                        text: "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }
        }

        RowButton {
            icon: "add"
            text: Tr.tr("Pair new device")
            disabled: !root.btEnabled
            onClicked: root.nState.openSubPage(2)
        }

        ToggleRow {
            groupStart: true
            // TRANSLATORS: adjective: other devices can find this computer
            text: Tr.trCtx("Discoverable", "bluetooth setting")
            subtext: Tr.tr("Allow nearby devices to find this computer while this page is open")
            disabled: !root.btEnabled
            checked: root.adapter?.discoverable ?? false
            onToggled: {
                if (root.adapter) {
                    if (checked)
                        root.adapter.pairable = true;
                    root.adapter.discoverable = checked;
                }
            }

            Behavior on opacity {
                Anim {}
            }
        }

        // Batteries of wireless devices (mice, keyboards, headsets...), from
        // UPower: the ones on their own USB receiver too, not only Bluetooth
        SectionHeader {
            visible: batteryList.count > 0
            text: Tr.tr("Device batteries")
        }

        Repeater {
            id: batteryList

            model: root.upowerDevices

            InfoRow {
                required property UPowerDevice modelData
                required property int index

                readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(modelData.state)

                icon: {
                    switch (modelData.type) {
                    case UPowerDeviceType.Mouse:
                        return "mouse";
                    case UPowerDeviceType.Keyboard:
                        return "keyboard";
                    case UPowerDeviceType.Headset:
                    case UPowerDeviceType.Headphones:
                        return "headphones";
                    case UPowerDeviceType.GamingInput:
                        return "sports_esports";
                    case UPowerDeviceType.Phone:
                        return "smartphone";
                    case UPowerDeviceType.Tablet:
                        return "tablet";
                    default:
                        return "battery_full";
                    }
                }
                label: modelData.model || Tr.tr("Wireless device")
                subtext: charging ? Tr.tr("Charging") : ""
                value: `${Math.round(modelData.percentage * 100)}%`
                iconColour: modelData.percentage <= 0.15 && !charging ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
