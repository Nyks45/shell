pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Add or edit a VPN provider. editingVpnIndex (-1 = add) is read from NexusState.
PageBase {
    id: root

    readonly property int editIndex: nState.editingVpnIndex
    readonly property bool editing: editIndex >= 0
    readonly property var existing: editing ? (VPN.providers[editIndex] ?? null) : null
    readonly property var builtInPresets: ({
            wireguard: "WireGuard",
            warp: "Cloudflare WARP",
            tailscale: "Tailscale",
            netbird: "NetBird"
        })
    property string providerType: "wireguard"
    property bool overrideCommands: false

    function splitCmd(arr: var): string {
        return arr?.join(" ") ?? "";
    }

    function joinCmd(str: string): var {
        const t = str.trim();
        return t.length > 0 ? t.split(/\s+/) : [];
    }

    function arrEq(a: var, b: var): bool {
        return a.length === b.length && a.every((x, i) => x === b[i]);
    }

    function selectType(typeId: string, resetDisplay: bool): void {
        const prevDefault = builtInPresets[providerType] ?? "";
        providerType = typeId;
        const itemMap = {
            wireguard: wireguardItem,
            warp: warpItem,
            tailscale: tailscaleItem,
            netbird: netbirdItem,
            custom: customItem
        };
        typeSelect.active = itemMap[typeId] ?? customItem;
        if (typeId !== "custom") {
            nameField.text = typeId;
            nameField.isError = false;
            if (resetDisplay || !displayField.text.trim() || displayField.text.trim() === prevDefault)
                displayField.text = builtInPresets[typeId] ?? typeId;
        } else {
            if (builtInPresets[nameField.text.trim()])
                nameField.text = "";
            if (resetDisplay && displayField.text.trim() === prevDefault)
                displayField.text = "";
            overrideCommands = true;
        }
    }

    function submit(): void {
        const name = root.providerType === "custom" ? nameField.text.trim() : root.providerType;
        if (name.length === 0) {
            nameField.isError = true;
            nameField.forceActiveFocus();
            return;
        }
        if (root.providerType === "wireguard" && interfaceField.text.trim().length === 0) {
            interfaceField.isError = true;
            interfaceField.forceActiveFocus();
            return;
        }

        const customCmds = root.providerType === "custom" || root.overrideCommands;
        const data = {
            name: name,
            displayName: displayField.text.trim() || root.builtInPresets[name] || name,
            interface: interfaceField.text.trim(),
            connectCmd: customCmds ? joinCmd(connectField.text) : [],
            disconnectCmd: customCmds ? joinCmd(disconnectField.text) : []
        };

        if (editing) {
            const needsReload = existing.id === VPN.selectedProvider && VPN.connected && (existing.name !== name || existing.interface !== data.interface || !arrEq(existing.connectCmd, data.connectCmd) || !arrEq(existing.disconnectCmd, data.disconnectCmd));
            if (needsReload)
                VPN.disconnect();
            VPN.updateProvider(editIndex, data);
            if (needsReload) {
                if (!VPN.connecting && !VPN.disconnecting) {
                    VPN.connect();
                } else if (VPN.disconnecting) {
                    let onConnChanged = () => {
                        if (onConnChanged && !VPN.disconnecting) {
                            VPN.disconnectingChanged.disconnect(onConnChanged);
                            onConnChanged = null;
                            if (!VPN.connected)
                                VPN.connect();
                        }
                    };
                    VPN.disconnectingChanged.connect(onConnChanged);
                }
            }
        } else {
            VPN.addProvider(data);
        }

        nState.closeSubPage();
    }

    title: editing ? Tr.tr("Edit VPN provider") : Tr.tr("Add VPN provider")
    isSubPage: true

    Component.onCompleted: {
        if (existing) {
            const typeId = builtInPresets[existing.name] ? existing.name : "custom";
            nameField.text = existing.name;
            displayField.text = existing.displayName;
            interfaceField.text = existing.interface;
            connectField.text = splitCmd(existing.connectCmd);
            disconnectField.text = splitCmd(existing.disconnectCmd);
            overrideCommands = typeId === "custom" || connectField.text.length > 0 || disconnectField.text.length > 0;
            selectType(typeId, false);
        } else {
            selectType("wireguard", true);
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SelectRow {
            id: typeSelect

            label: Tr.tr("VPN type")
            subtext: root.providerType === "custom" ? Tr.tr("Run your own connect and disconnect commands") : Tr.tr("Uses the built-in integration for %1").arg(root.builtInPresets[root.providerType] ?? root.providerType)
            segmentedAllowed: false
            menuItems: [wireguardItem, warpItem, tailscaleItem, netbirdItem, customItem]
            onSelected: item => root.selectType(String(item.value), true)

            MenuItem {
                id: wireguardItem

                icon: "vpn_key"
                text: "WireGuard"
                value: "wireguard"
            }

            MenuItem {
                id: warpItem

                icon: "cloud"
                text: "Cloudflare WARP"
                value: "warp"
            }

            MenuItem {
                id: tailscaleItem

                icon: "hub"
                text: "Tailscale"
                value: "tailscale"
            }

            MenuItem {
                id: netbirdItem

                icon: "share"
                text: "NetBird"
                value: "netbird"
            }

            MenuItem {
                id: customItem

                icon: "terminal"
                text: Tr.tr("Custom command")
                value: "custom"
            }
        }

        StyledTextField {
            id: nameField

            Layout.fillWidth: true
            visible: root.providerType === "custom"
            placeholderText: Tr.tr("Provider identifier")
            leadingIcon: "vpn_key"
            supportingText: Tr.tr("Short internal name, e.g. openvpn or work-vpn")
            errorText: Tr.tr("Provider identifier is required")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: displayField.forceActiveFocus()
        }

        StyledTextField {
            id: displayField

            Layout.fillWidth: true
            placeholderText: Tr.tr("Display name")
            // TRANSLATORS: the name shown in the VPN provider list on the network page
            supportingText: Tr.tr("Shown in the Network page list")
            leadingIcon: "label"
            inputMethodHints: Qt.ImhNoPredictiveText

            onAccepted: interfaceField.visible ? interfaceField.forceActiveFocus() : (connectField.visible ? connectField.forceActiveFocus() : root.submit())
        }

        StyledTextField {
            id: interfaceField

            Layout.fillWidth: true
            visible: root.providerType === "wireguard" || root.providerType === "custom" || root.overrideCommands
            placeholderText: root.providerType === "wireguard" ? Tr.tr("WireGuard interface / profile (e.g. wg0)") : Tr.trCtx("Interface", "network interface")
            leadingIcon: "lan"
            supportingText: root.providerType === "wireguard" ? Tr.tr("Config or interface name in /etc/wireguard (required for WireGuard)") : Tr.tr("Network interface used to detect connection status")
            errorText: Tr.tr("WireGuard interface / profile name is required")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: connectField.visible ? connectField.forceActiveFocus() : root.submit()
        }

        ToggleRow {
            visible: root.providerType !== "custom"
            text: Tr.tr("Override connect/disconnect commands")
            subtext: Tr.tr("Replace the built-in CLI commands with custom ones")
            checked: root.overrideCommands
            onToggled: root.overrideCommands = checked
        }

        SectionHeader {
            visible: root.providerType === "custom" || root.overrideCommands
            text: root.providerType === "custom" ? Tr.tr("Commands") : Tr.tr("Custom commands (optional)")
        }

        StyledTextField {
            id: connectField

            Layout.fillWidth: true
            visible: root.providerType === "custom" || root.overrideCommands
            placeholderText: Tr.tr("Connect command")
            leadingIcon: "play_arrow"
            supportingText: root.providerType === "custom" ? Tr.tr("Command run to connect, e.g. wg-quick up myvpn") : Tr.tr("Leave empty to use the built-in default")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: disconnectField.forceActiveFocus()
        }

        StyledTextField {
            id: disconnectField

            Layout.fillWidth: true
            visible: root.providerType === "custom" || root.overrideCommands
            placeholderText: Tr.tr("Disconnect command")
            leadingIcon: "stop"
            supportingText: root.providerType === "custom" ? Tr.tr("Command run to disconnect, e.g. wg-quick down myvpn") : Tr.tr("Leave empty to use the built-in default")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: root.submit()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: (root.editing ? Tokens.spacing.medium : Tokens.spacing.extraSmall) - parent.spacing
            spacing: Tokens.spacing.small

            IconTextButton {
                visible: root.editing
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                inactiveColour: Colours.palette.m3errorContainer
                inactiveOnColour: Colours.palette.m3onErrorContainer
                iconLabel.fill: 1
                iconLabel.grade: 25
                icon: "delete_forever"
                text: Tr.tr("Delete")
                onClicked: confirmDialog.ask({
                    header: Tr.tr("Delete VPN provider?"),
                    body: Tr.tr("Removes %1 from your saved VPN providers.").arg(root.existing?.name ?? ""),
                    confirmLabel: Tr.tr("Delete"),
                    onConfirm: () => {
                        if (root.existing?.id === VPN.selectedProvider && VPN.connected)
                            VPN.disconnect();
                        VPN.deleteProvider(root.editIndex);
                        root.nState.closeSubPage();
                    }
                })
            }

            Item {
                Layout.fillWidth: true
            }

            ButtonRow {
                spacing: parent.spacing

                TextButton {
                    isRound: true
                    shapeMorph: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    type: TextButton.Tonal
                    text: Tr.trCtx("Cancel", "button")
                    onClicked: root.nState.closeSubPage()
                }

                TextButton {
                    isRound: true
                    shapeMorph: true
                    horizontalPadding: Tokens.padding.extraLarge
                    verticalPadding: Tokens.padding.medium
                    text: root.editing ? Tr.trCtx("Save", "button") : Tr.trCtx("Add", "button")
                    disabled: root.providerType === "custom" ? !nameField.text.trim() : (root.providerType === "wireguard" ? !interfaceField.text.trim() : false)
                    onClicked: root.submit()
                }
            }
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}
