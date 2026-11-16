pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus

// A quick setting's list, in the island's style: a header (its icon, name, state and switch),
// then its rows as cards. "network": Wi-Fi networks or the Ethernet devices; "bluetooth": the
// devices; "audio": the outputs and inputs.
Item {
    id: root

    required property string kind

    signal closeRequested

    readonly property bool wired: !!Nmcli.activeEthernet && !Nmcli.active
    readonly property bool btOn: Bluetooth.defaultAdapter?.enabled ?? false

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // The header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                color: Colours.palette.m3primary

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.kind === "network" ? (root.wired ? "lan" : "wifi") : root.kind === "bluetooth" ? "bluetooth" : "volume_up"
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.small
                    fill: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    text: root.kind === "network" ? (root.wired ? Tr.tr("Ethernet") : Tr.tr("Wi-Fi")) : root.kind === "bluetooth" ? Tr.tr("Bluetooth") : Tr.tr("Sound")
                    font: Tokens.font.title.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.kind === "network")
                            return root.wired ? (Nmcli.activeEthernet?.connection ?? "") : Nmcli.active?.ssid ?? (Nmcli.wifiEnabled ? Tr.tr("Not connected") : Tr.tr("Off"));
                        if (root.kind === "bluetooth") {
                            const n = Bluetooth.devices.values.filter(d => d.connected).length;
                            return !root.btOn ? Tr.tr("Off") : n ? Tr.tr("%1 connected").arg(n) : Tr.tr("On");
                        }
                        return Audio.sink?.description ?? "";
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            // Wi-Fi: search again; Bluetooth: look for new devices
            IconButton {
                visible: (root.kind === "network" && !root.wired && Nmcli.wifiEnabled) || (root.kind === "bluetooth" && root.btOn)
                type: IconButton.Text
                icon: root.kind === "bluetooth" ? ((Bluetooth.defaultAdapter?.discovering ?? false) ? "search_off" : "bluetooth_searching") : "refresh"
                onClicked: {
                    if (root.kind === "bluetooth") {
                        const a = Bluetooth.defaultAdapter;
                        if (a)
                            a.discovering = !a.discovering;
                    } else {
                        Nmcli.rescanWifi();
                    }
                }
            }

            StyledSwitch {
                visible: root.kind !== "audio" && !(root.kind === "network" && root.wired)
                checked: root.kind === "network" ? Nmcli.wifiEnabled : root.btOn
                onToggled: {
                    if (root.kind === "network") {
                        Nmcli.toggleWifi();
                    } else {
                        const a = Bluetooth.defaultAdapter;
                        if (a)
                            a.enabled = !a.enabled;
                    }
                }
            }

            IconButton {
                type: IconButton.Text
                icon: "open_in_new"
                onClicked: {
                    WindowFactory.createAt(root.kind === "audio" ? "audio" : root.kind === "bluetooth" ? "devices" : "network", []);
                    root.closeRequested();
                }
            }

            IconButton {
                type: IconButton.Tonal
                icon: "close"
                onClicked: root.closeRequested()
            }
        }

        // The rows
        ListView {
            id: rows

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Tokens.spacing.extraSmall
            boundsBehavior: Flickable.StopAtBounds
            model: {
                if (root.kind === "network") {
                    if (root.wired)
                        return Nmcli.ethernetDevices.map(d => ({
                                    t: "eth",
                                    d: d
                                }));
                    return [...Nmcli.networks].sort((a, b) => (b.active - a.active) || (b.strength - a.strength)).map(n => ({
                                t: "wifi",
                                d: n
                            }));
                }
                if (root.kind === "bluetooth")
                    return [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)).map(d => ({
                                t: "bt",
                                d: d
                            }));
                const nodes = Pipewire.nodes.values.filter(n => n.isSink !== undefined && !n.isStream && n.audio);
                return [...nodes.filter(n => n.isSink).map(n => ({
                                t: "out",
                                d: n
                            })), ...nodes.filter(n => !n.isSink).map(n => ({
                                t: "in",
                                d: n
                            }))];
            }

            delegate: StyledRect {
                id: row

                required property var modelData
                required property int index
                readonly property var d: modelData.d
                readonly property bool active: {
                    switch (modelData.t) {
                    case "wifi":
                        return d.active;
                    case "eth":
                        return d.connected;
                    case "bt":
                        return d.connected;
                    case "out":
                        return Audio.sink === d;
                    default:
                        return Audio.source === d;
                    }
                }
                readonly property bool busy: modelData.t === "bt" && (d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
                // A sound section starts here (Outputs / Inputs)
                readonly property string section: modelData.t === "out" && index === 0 ? Tr.tr("Outputs") : modelData.t === "in" && (index === 0 || rows.model[index - 1]?.t !== "in") ? Tr.tr("Inputs") : ""

                width: rows.width
                implicitHeight: 44 + (section ? sectionLabel.implicitHeight + 4 : 0)
                color: "transparent"

                StyledText {
                    id: sectionLabel

                    visible: row.section !== ""
                    x: Tokens.padding.small
                    text: row.section
                    color: Colours.palette.m3primary
                    font: Tokens.font.label.medium
                }

                StyledRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 44
                    radius: Tokens.rounding.large
                    color: row.active ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                    StateLayer {
                        disabled: row.busy
                        onClicked: {
                            switch (row.modelData.t) {
                            case "wifi":
                                if (row.d.active)
                                    Nmcli.disconnectFromNetwork();
                                else
                                    NetworkConnection.handleConnect(row.d, null, () => {
                                        // A password is needed: in the settings
                                        WindowFactory.createAt("network", []);
                                        root.closeRequested();
                                    });
                                break;
                            case "eth":
                                if (row.d.connected)
                                    Nmcli.disconnectEthernet(row.d.connection, () => {});
                                else
                                    Nmcli.connectEthernet(row.d.connection || "", row.d.iface || "", () => {});
                                break;
                            case "bt":
                                row.d.connected = !row.d.connected;
                                break;
                            case "out":
                                Audio.setAudioSink(row.d);
                                break;
                            default:
                                Audio.setAudioSource(row.d);
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: {
                                switch (row.modelData.t) {
                                case "wifi":
                                    return row.d.strength > 75 ? "network_wifi" : row.d.strength > 50 ? "network_wifi_3_bar" : row.d.strength > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
                                case "eth":
                                    return "settings_ethernet";
                                case "bt":
                                    return Icons.getBluetoothIcon(row.d.icon);
                                case "out":
                                    return "speaker";
                                default:
                                    return "mic";
                                }
                            }
                            color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                            fill: row.active ? 1 : 0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                switch (row.modelData.t) {
                                case "wifi":
                                    return row.d.ssid;
                                case "eth":
                                    return row.d.connection || row.d.iface;
                                case "bt":
                                    return row.d.name || row.d.deviceName;
                                default:
                                    return row.d.description || row.d.nickname || row.d.name;
                                }
                            }
                            color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            visible: row.modelData.t === "wifi" && row.d.isSecure
                            text: "lock"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            visible: text !== ""
                            text: row.busy ? Tr.tr("…") : row.modelData.t === "bt" && row.d.batteryAvailable ? `${Math.round(row.d.battery * 100)}%` : row.active ? (row.modelData.t === "out" || row.modelData.t === "in" ? Tr.tr("In use") : Tr.tr("Connected")) : ""
                            color: row.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: rows.count === 0
                text: root.kind === "bluetooth" ? (root.btOn ? Tr.tr("No devices yet: search for new ones") : Tr.tr("Bluetooth is off")) : root.kind === "network" ? (Nmcli.wifiEnabled ? Tr.tr("No networks found") : Tr.tr("Wi-Fi is off")) : Tr.tr("No sound devices")
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
