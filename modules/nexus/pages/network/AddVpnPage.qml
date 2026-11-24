pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.modules.nexus.common

// Add or edit a VPN provider. editingVpnIndex (-1 = add) is read from NexusState.
PageBase {
    id: root

    readonly property int editIndex: nState.editingVpnIndex
    readonly property bool editing: editIndex >= 0
    readonly property var existing: editing ? (VPN.providers[editIndex] ?? null) : null
    readonly property var selectedAdapter: VPN.adapterFor(root.providerType)
    readonly property var builtInPresets: ({
            wireguard: "WireGuard",
            nm: "NetworkManager VPN",
            warp: "Cloudflare WARP",
            tailscale: "Tailscale",
            netbird: "NetBird"
        })
    property string providerType: "wireguard"
    property bool overrideCommands: false
    // Overrides the person turned on (or a saved built-in provider had): a
    // built-in type keeps its own commands otherwise ("Custom" forces them on,
    // and switching back from it mustn't keep them)
    property bool overridesChosen: false
    property var nmProfiles: []
    property bool importingConfig: false
    property bool missingOpenvpnPlugin: false
    property string lastImportFile: ""
    property bool _switchToNmOnImport: false

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
            nm: nmItem,
            warp: warpItem,
            tailscale: tailscaleItem,
            netbird: netbirdItem,
            custom: customItem
        };
        typeSelect.active = itemMap[typeId] ?? customItem;
        missingOpenvpnPlugin = false;
        if (typeId !== "custom") {
            nameField.text = typeId;
            nameField.isError = false;
            overrideCommands = overridesChosen;
            if (resetDisplay || !displayField.text.trim() || displayField.text.trim() === prevDefault)
                displayField.text = builtInPresets[typeId] ?? typeId;
            if (typeId === "nm")
                refreshNmProfiles();
        } else {
            if (builtInPresets[nameField.text.trim()])
                nameField.text = "";
            if (resetDisplay && displayField.text.trim() === prevDefault)
                displayField.text = "";
            overrideCommands = true;
        }
    }

    function refreshNmProfiles(): void {
        nmListProc.running = false;
        nmListProc.running = true;
    }

    function importNmConfig(path: string): void {
        if (!path)
            return;
        lastImportFile = path;
        missingOpenvpnPlugin = false;
        importingConfig = true;
        const type = path.toLowerCase().endsWith(".ovpn") ? "openvpn" : "wireguard";
        nmImportProc.command = ["nmcli", "connection", "import", "type", type, "file", path];
        nmImportProc.outText = "";
        nmImportProc.errText = "";
        nmImportProc.pending = 3;
        nmImportProc.running = false;
        nmImportProc.running = true;
    }

    function submit(): void {
        const name = root.providerType === "custom" ? nameField.text.trim() : root.providerType;
        if (name.length === 0) {
            nameField.isError = true;
            nameField.forceActiveFocus();
            return;
        }
        if ((root.providerType === "wireguard" || root.providerType === "nm") && interfaceField.text.trim().length === 0) {
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
        VPN.refreshAvailability();
        if (existing) {
            const typeId = builtInPresets[existing.name] ? existing.name : "custom";
            nameField.text = existing.name;
            displayField.text = existing.displayName;
            interfaceField.text = existing.interface;
            connectField.text = splitCmd(existing.connectCmd);
            disconnectField.text = splitCmd(existing.disconnectCmd);
            overridesChosen = typeId !== "custom" && (connectField.text.length > 0 || disconnectField.text.length > 0);
            overrideCommands = typeId === "custom" || overridesChosen;
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
            menuItems: [wireguardItem, nmItem, warpItem, tailscaleItem, netbirdItem, customItem]
            onSelected: item => root.selectType(String(item.value), true)

            MenuItem {
                id: wireguardItem

                icon: "vpn_key"
                text: "WireGuard"
                value: "wireguard"
            }

            MenuItem {
                id: nmItem

                icon: "vpn_lock"
                text: Tr.tr("NetworkManager VPN (OpenVPN / WireGuard)")
                value: "nm"
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

        RequirementRow {
            readonly property string pkgName: root.selectedAdapter?.pkgName ?? ""
            readonly property string pkgSource: root.selectedAdapter?.pkgSource ?? "repo"
            readonly property string pkgLabel: root.selectedAdapter?.pkgLabel || (root.builtInPresets[root.providerType] ?? root.providerType)

            visible: root.providerType !== "custom" && root.providerType !== "nm" && pkgName.length > 0 && !VPN.isInstalled(root.providerType)
            Layout.bottomMargin: Tokens.spacing.small
            icon: "extension_off"
            text: Tr.tr("%1 isn't installed").arg(pkgLabel)
            subtext: Tr.tr("Install %1 so Settings can connect this VPN.").arg(pkgName)
            actionText: Packages.busy[`${pkgSource}:${pkgName}`] ? "" : Tr.tr("Install")
            onAction: Packages.install({
                source: pkgSource,
                name: pkgName
            }, () => VPN.refreshAvailability())
        }

        RequirementRow {
            readonly property string svc: root.selectedAdapter?.service ?? ""

            visible: root.providerType !== "custom" && root.providerType !== "nm" && VPN.isInstalled(root.providerType) && svc.length > 0 && svc !== "NetworkManager" && !VPN.isServiceActive(root.providerType)
            Layout.bottomMargin: Tokens.spacing.small
            neutral: true
            icon: "play_circle"
            text: Tr.tr("%1 service isn't running").arg(root.builtInPresets[root.providerType] ?? root.providerType)
            subtext: Tr.tr("Start and enable %1 before connecting.").arg(svc)
            actionText: Admin.busy ? "" : Tr.tr("Start service")
            onAction: Admin.exec(["systemctl", "enable", "--now", svc], Tr.tr("Start %1 service").arg(root.builtInPresets[root.providerType] ?? root.providerType), () => VPN.refreshAvailability())
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

        RowButton {
            visible: root.providerType === "wireguard"
            icon: "upload_file"
            text: Tr.tr("Import WireGuard .conf file…")
            subtext: root.importingConfig ? Tr.tr("Importing into NetworkManager…") : Tr.tr("Imports into NetworkManager so it connects without wg-quick or root prompts")
            disabled: root.importingConfig
            onClicked: {
                root._switchToNmOnImport = true;
                configFileDialog.open();
            }
        }

        RowButton {
            visible: root.providerType === "nm"
            icon: "upload_file"
            text: Tr.tr("Import config file (.conf / .ovpn)…")
            subtext: root.importingConfig ? Tr.tr("Importing into NetworkManager…") : Tr.tr("An OpenVPN (.ovpn) or WireGuard (.conf) profile, kept off until you connect it")
            disabled: root.importingConfig
            onClicked: {
                root._switchToNmOnImport = false;
                configFileDialog.open();
            }
        }

        RequirementRow {
            visible: root.providerType === "nm" && root.missingOpenvpnPlugin
            icon: "extension"
            text: Tr.tr("NetworkManager OpenVPN plugin required")
            subtext: Tr.tr("Install networkmanager-openvpn to import and connect .ovpn profiles")
            actionText: Tr.tr("Install")
            onAction: Packages.install({
                source: "repo",
                name: "networkmanager-openvpn"
            }, () => {
                root.missingOpenvpnPlugin = false;
                if (root.lastImportFile)
                    root.importNmConfig(root.lastImportFile);
            })
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.providerType === "nm" && root.nmProfiles.length > 0
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Existing NetworkManager VPN profiles")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.nmProfiles

                    TextButton {
                        required property var modelData

                        text: `${modelData.name} (${modelData.type})`
                        isToggle: true
                        followChecked: true
                        checked: interfaceField.text.trim() === modelData.name
                        type: TextButton.Tonal
                        onClicked: {
                            interfaceField.text = modelData.name;
                            interfaceField.isError = false;
                            if (!displayField.text.trim() || displayField.text.trim() === root.builtInPresets.nm)
                                displayField.text = modelData.name;
                        }
                    }
                }
            }
        }

        StyledTextField {
            id: interfaceField

            Layout.fillWidth: true
            visible: root.providerType === "wireguard" || root.providerType === "nm" || root.providerType === "custom" || root.overrideCommands
            placeholderText: root.providerType === "nm" ? Tr.tr("NetworkManager VPN profile name") : root.providerType === "wireguard" ? Tr.tr("WireGuard interface / profile (e.g. wg0)") : Tr.trCtx("Interface", "network interface")
            leadingIcon: "lan"
            supportingText: root.providerType === "nm" ? Tr.tr("NetworkManager connection name (or import a file above)") : root.providerType === "wireguard" ? Tr.tr("Config or interface name in /etc/wireguard (required for WireGuard)") : Tr.tr("Network interface used to detect connection status")
            errorText: root.providerType === "nm" ? Tr.tr("NetworkManager VPN profile name is required") : Tr.tr("WireGuard interface / profile name is required")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: connectField.visible ? connectField.forceActiveFocus() : root.submit()
        }

        ToggleRow {
            visible: root.providerType !== "custom"
            text: Tr.tr("Override connect/disconnect commands")
            subtext: Tr.tr("Replace the built-in CLI commands with custom ones")
            checked: root.overrideCommands
            onToggled: {
                root.overrideCommands = checked;
                root.overridesChosen = checked;
            }
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
                    disabled: root.providerType === "custom" ? !nameField.text.trim() : ((root.providerType === "wireguard" || root.providerType === "nm") ? !interfaceField.text.trim() : false)
                    onClicked: root.submit()
                }
            }
        }

        FileDialog {
            id: configFileDialog

            title: Tr.tr("Import VPN configuration")
            filterLabel: Tr.tr("VPN configurations")
            filters: ["conf", "ovpn"]
            onAccepted: path => root.importNmConfig(path)
        }

        Process {
            id: nmListProc

            command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const list = [];
                    for (const raw of text.split("\n")) {
                        if (!raw)
                            continue;
                        const parts = [];
                        let cur = "";
                        for (let i = 0; i < raw.length; i++) {
                            if (raw[i] === "\\" && i + 1 < raw.length && (raw[i + 1] === ":" || raw[i + 1] === "\\")) {
                                cur += raw[++i];
                            } else if (raw[i] === ":") {
                                parts.push(cur);
                                cur = "";
                            } else {
                                cur += raw[i];
                            }
                        }
                        parts.push(cur);
                        if (parts[1] === "vpn" || parts[1] === "wireguard")
                            list.push({
                                name: parts[0],
                                type: parts[1]
                            });
                    }
                    root.nmProfiles = list;
                }
            }
        }

        Process {
            id: nmImportProc

            property string outText: ""
            property string errText: ""
            property int exitCode: -1
            // Exit and the two streams can come in any order: the result is read
            // once all three are in (the error text was empty otherwise)
            property int pending: 0

            function settle(): void {
                if (--pending > 0)
                    return;
                root.importingConfig = false;
                if (exitCode === 0) {
                    const m = outText.match(/'([^']+)'/);
                    const uuid = outText.match(/\(([0-9a-f-]{36})\)/i);
                    const fallbackName = root.lastImportFile.split("/").pop().replace(/\.(ovpn|conf)$/i, "");
                    const connName = m ? m[1] : fallbackName;
                    interfaceField.text = connName;
                    interfaceField.isError = false;
                    if (!displayField.text.trim() || displayField.text.trim() === root.builtInPresets.nm || displayField.text.trim() === root.builtInPresets.wireguard)
                        displayField.text = connName;
                    if (root._switchToNmOnImport) {
                        root._switchToNmOnImport = false;
                        root.selectType("nm", false);
                        interfaceField.text = connName;
                        interfaceField.isError = false;
                    }
                    // nmcli imports with autoconnect on: a full-tunnel profile would
                    // come up by itself right away; it connects only when asked
                    nmAutoProc.command = ["nmcli", "connection", "modify", uuid ? uuid[1] : connName, "connection.autoconnect", "no"];
                    nmAutoProc.running = true;
                    root.refreshNmProfiles();
                    Toaster.toast(Tr.tr("VPN profile imported"), Tr.tr("%1 · connects only when you turn it on").arg(connName), "vpn_lock");
                } else {
                    const msg = errText.trim() || outText.trim();
                    // An .ovpn file NetworkManager can't read without its OpenVPN plugin
                    if ((/\.ovpn$/i.test(root.lastImportFile) || /openvpn/i.test(msg)) && /plugin|vpn service|not installed|support|unknown/i.test(msg))
                        root.missingOpenvpnPlugin = true;
                    Toaster.toast(Tr.tr("Couldn't import VPN config"), msg || Tr.tr("Check that the config file is valid"), "error");
                }
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    nmImportProc.outText = text;
                    nmImportProc.settle();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    nmImportProc.errText = text;
                    nmImportProc.settle();
                }
            }
            onExited: code => {
                exitCode = code;
                settle();
            }
        }

        Process {
            id: nmAutoProc
        }

        ConfirmDialog {
            id: confirmDialog

            hostFlickable: root.flickable
        }
    }
}
