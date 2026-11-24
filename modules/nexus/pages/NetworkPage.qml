pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Network")

    Component.onCompleted: VPN.refreshSplit()
    onVisibleChanged: if (visible)
        VPN.refreshSplit()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.hasWifiHardware && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.hasWifiHardware && Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        Loader {
            Layout.fillWidth: true
            active: Nmcli.hasAvailableEthernet
            visible: active
            asynchronous: true

            sourceComponent: EthernetSection {
                nState: root.nState
                cappedWidth: root.cappedWidth
            }
        }

        ToggleRow {
            visible: Nmcli.hasWifiHardware
            groupStart: true
            text: Tr.tr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        NetworkList {
            visible: Nmcli.hasWifiHardware
            Layout.bottomMargin: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? 0 : -parent.spacing
            nState: root.nState
            limit: GlobalConfig.nexus.maxNetworksShown

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // All networks button, only when > max networks
        RowButton {
            readonly property bool shown: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown

            visible: Nmcli.hasWifiHardware && (shown || showAllAnim.running)
            Layout.preferredHeight: shown ? implicitHeight : 0
            clip: showAllAnim.running

            icon: "expand_content"
            // TRANSLATORS: %1 = number of networks found
            text: Tr.tr("Show all networks (%1)").arg(Nmcli.networks.length)
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(5) // All networks sub-page

            Behavior on Layout.preferredHeight {
                Anim {
                    id: showAllAnim

                    type: Anim.DefaultEffects
                }
            }
        }

        // Saved networks button
        RowButton {
            visible: Nmcli.hasWifiHardware
            icon: "bookmark"
            text: Tr.tr("Saved networks")
            trailingIcon: "chevron_right"
            onClicked: root.nState.openSubPage(6) // Saved networks sub-page
        }

        RowButton {
            visible: Nmcli.hasWifiHardware
            icon: "add"
            text: Tr.tr("Add network")
            disabled: !Nmcli.wifiEnabled
            onClicked: root.nState.openSubPage(2) // Add network sub-page
        }

        // ---- VPN -------------------------------------------------------------
        ToggleRow {
            Layout.fillWidth: true
            groupStart: true
            text: Tr.tr("VPN")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: VPN.connected
            // Connectable as long as there's an installed provider and we're not mid-switch.
            disabled: VPN.connecting || VPN.disconnecting || VPN.providers.length === 0 || VPN.activeCliMissing
            onToggled: VPN.toggle()

            Timer {
                running: root.visible
                repeat: true
                triggeredOnStart: true
                interval: 5000
                onTriggered: {
                    VPN.checkStatus();
                    if (VPN.connected)
                        VPN.refreshStats();
                }
            }

            Connections {
                function onVisibleChanged(): void {
                    if (root.visible) {
                        VPN.refreshAvailability();
                        AdBlocker.refresh();
                    }
                }

                target: root
            }
        }

        ItemList {
            id: providerList

            showList: true
            placeholderIcon: "add_circle"
            placeholderText: Tr.tr("No VPN providers configured")

            model: ScriptModel {
                values: [...VPN.providers]
            }

            delegate: Item {
                id: provider

                required property var modelData // QML types are annoying (causes null errors on destruction if typed correctly)
                required property int index
                readonly property bool isSelected: modelData.id === VPN.selectedProvider
                readonly property bool isConnected: isSelected && VPN.connected

                anchors.left: providerList.list.contentItem.left
                anchors.right: providerList.list.contentItem.right
                implicitHeight: providerLayout.implicitHeight + providerLayout.anchors.margins * 2

                StateLayer {
                    disabled: provider.isSelected
                    radius: Tokens.rounding.extraSmall
                    onClicked: {
                        if (!provider.isSelected)
                            VPN.setActiveProvider(provider.index);
                    }
                }

                RowLayout {
                    id: providerLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        id: providerIcon

                        text: provider.isConnected || provider.isSelected ? "vpn_key" : "vpn_key_off"
                        fill: provider.isConnected ? 1 : 0
                        color: provider.isConnected || provider.isSelected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        animate: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: provider.modelData.displayName || provider.modelData.name
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!provider.isSelected)
                                    return provider.modelData.interface || provider.modelData.name;
                                if (VPN.connecting)
                                    return Tr.tr("Connecting...");
                                if (VPN.disconnecting)
                                    return Tr.tr("Disconnecting...");
                                switch (VPN.status.state) {
                                case "connected":
                                    return [Tr.trCtx("Connected", "vpn state"), VPN.serverLocation, (VPN.bytesIn && VPN.bytesOut) ? `↓ ${VPN.bytesIn}  ↑ ${VPN.bytesOut}` : ""].filter(s => s).join(" • ");
                                case "connecting":
                                    return Tr.tr("Connecting...");
                                case "needs-auth":
                                    return VPN.status.reason ? Tr.trMarked(VPN.status.reason) : Tr.tr("Authentication required");
                                case "needs-operator":
                                    return VPN.status.reason ? Tr.trMarked(VPN.status.reason) : Tr.tr("Operator permission needed");
                                case "service-stopped":
                                    return VPN.status.reason ? Tr.trMarked(VPN.status.reason) : Tr.tr("Service not running");
                                case "missing-cli":
                                    return VPN.status.reason ? Tr.trMarked(VPN.status.reason) : Tr.tr("VPN client not installed");
                                case "error":
                                    return VPN.status.reason ? Tr.trMarked(VPN.status.reason) : Tr.tr("An error occurred");
                                default:
                                    return Tr.trCtx("Selected • Ready to connect", "vpn status");
                                }
                            }
                            color: {
                                if (!provider.isSelected)
                                    return Colours.palette.m3onSurfaceVariant;
                                switch (VPN.status.state) {
                                case "connected":
                                    return Colours.palette.m3primary;
                                case "needs-auth":
                                case "needs-operator":
                                case "service-stopped":
                                case "missing-cli":
                                case "error":
                                    return Colours.palette.m3error;
                                default:
                                    return Colours.palette.m3secondary;
                                }
                            }
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    Item {
                        id: providerDetailBox

                        readonly property string displayIface: (provider.isSelected ? VPN.activeDevice : "") || provider.modelData.interface

                        Layout.rightMargin: Tokens.spacing.small
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        opacity: provider.isConnected && root?.cappedWidth > Tokens.sizes.nexus.networkShowVpnDetailWidth ? 1 : 0
                        visible: opacity > 0

                        implicitWidth: provider.isConnected && root?.cappedWidth > Tokens.sizes.nexus.networkShowVpnDetailWidth ? providerDetailRow.implicitWidth : 0
                        implicitHeight: providerDetailRow.implicitHeight

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        RowLayout {
                            id: providerDetailRow

                            anchors.right: parent.right
                            spacing: Tokens.spacing.large

                            ColumnLayout {
                                visible: providerDetailBox.displayIface.length > 0
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: Tr.trCtx("Interface", "network interface")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: providerDetailBox.displayIface
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            ColumnLayout {
                                visible: VPN.pingMs >= 0
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: Tr.trCtx("Current ping", "round-trip latency to the VPN endpoint")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: Tokens.spacing.small

                                    StyledRect {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: Math.round(Tokens.font.body.small.pointSize * 0.7)
                                        implicitHeight: implicitWidth
                                        radius: Tokens.rounding.full
                                        color: VPN.pingMs <= 80 ? Colours.palette.m3primary : VPN.pingMs <= 150 ? Colours.palette.m3tertiary : Colours.palette.m3error
                                    }

                                    StyledText {
                                        text: Tr.tr("%1 ms").arg(VPN.pingMs)
                                        color: Colours.palette.m3outline
                                        font: Tokens.font.label.small
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    TextButton {
                        text: provider.isConnected ? Tr.trCtx("Disconnect", "button") : Tr.trCtx("Connect", "button")
                        type: TextButton.Tonal
                        disabled: VPN.connecting || VPN.disconnecting
                        onClicked: {
                            if (provider.isConnected)
                                VPN.disconnect();
                            else
                                VPN.connectProvider(provider.modelData.id);
                        }
                    }

                    IconButton {
                        implicitWidth: implicitHeight + (Tokens.padding.large - padding) * 2
                        type: IconButton.Text
                        isRound: true
                        icon: "edit"
                        onClicked: {
                            root.nState.editingVpnIndex = provider.index;
                            root.nState.openSubPage(4); // Add/edit provider sub-page
                        }
                    }
                }
            }
        }

        RequirementRow {
            visible: VPN.selected !== null && VPN.activeCliMissing && VPN.active.pkgName.length > 0
            icon: "extension_off"
            text: Tr.tr("%1 isn't installed").arg(VPN.active.pkgLabel || VPN.active.displayName)
            subtext: Tr.tr("Install %1 so Settings can connect this VPN.").arg(VPN.active.pkgName)
            actionText: Packages.busy[`${VPN.active.pkgSource}:${VPN.active.pkgName}`] ? "" : Tr.tr("Install")
            onAction: Packages.install({
                source: VPN.active.pkgSource,
                name: VPN.active.pkgName
            }, () => {
                VPN.refreshAvailability();
                VPN.checkStatus();
            })
        }

        RequirementRow {
            visible: VPN.selected !== null && !VPN.activeCliMissing && (VPN.activeServiceStopped || VPN.status.state === "service-stopped") && VPN.activeServiceUnit.length > 0
            icon: "play_circle"
            text: Tr.tr("%1 service isn't running").arg(VPN.active.displayName)
            subtext: Tr.tr("Start and enable %1 so Settings can connect this VPN.").arg(VPN.activeServiceUnit)
            actionText: Admin.busy ? "" : Tr.tr("Start service")
            onAction: Admin.exec(["systemctl", "enable", "--now", VPN.activeServiceUnit], Tr.tr("Start %1 service").arg(VPN.active.displayName), () => {
                VPN.refreshAvailability();
                VPN.checkStatus();
            })
        }

        RequirementRow {
            visible: VPN.selected !== null && VPN.status.state === "needs-operator"
            icon: "admin_panel_settings"
            text: Tr.tr("Allow your user to control Tailscale")
            subtext: Tr.tr("Tailscale requires operator permission before Settings can connect without sudo.")
            actionText: Admin.busy ? "" : Tr.tr("Allow my user")
            onAction: Admin.run("vpn-tailscale-operator", [], Tr.tr("Allow Tailscale control"), ok => {
                if (ok)
                    VPN.connect();
            })
        }

        RequirementRow {
            visible: VPN.selected !== null && VPN.status.state === "needs-auth" && VPN.status.authUrl.length > 0
            icon: "open_in_new"
            text: Tr.tr("Sign in to %1").arg(VPN.active.displayName)
            subtext: Tr.tr("Finish authentication in your browser, then return here.")
            actionText: Tr.tr("Open login page")
            onAction: Qt.openUrlExternally(VPN.status.authUrl)
        }

        // Per-app VPN split tunneling
        NavRow {
            icon: "alt_route"
            text: Tr.tr("App routing")
            subtext: VPN.splitMode === "include"
                ? Tr.trN("Only %n app uses the VPN", "Only %n apps use the VPN", VPN.splitApps.length)
                : VPN.splitMode === "exclude"
                    ? Tr.trN("%n app bypasses the VPN", "%n apps bypass the VPN", VPN.splitApps.length)
                    : Tr.tr("All apps use the VPN")
            onClicked: root.nState.openSubPage(8)
        }

        // Add provider
        RowButton {
            icon: "add"
            text: Tr.tr("Add provider")
            onClicked: {
                root.nState.editingVpnIndex = -1;
                root.nState.openSubPage(4); // Add/edit provider sub-page
            }
        }

        // ---- Ad blocker ------------------------------------------------------
        SectionHeader {
            text: Tr.tr("Ad blocker")
        }

        ToggleRow {
            visible: AdBlocker.installed && AdBlocker.configured
            text: Tr.tr("System-wide ad blocker")
            subtext: {
                if (AdBlocker.active)
                    return Tr.tr("Blocking ads & trackers · %1 blocked (%2%)").arg(AdBlocker.formatCompactCount(AdBlocker.stats.numBlockedFiltering ?? 0)).arg((AdBlocker.stats.blockedPercent ?? 0).toFixed(1));
                if (AdBlocker.paused)
                    return Tr.tr("Paused · %1 remaining").arg(AdBlocker.formatPauseCountdown(AdBlocker.pauseRemainingSec));
                return Tr.tr("Off: using your normal network DNS");
            }
            checked: AdBlocker.active
            disabled: AdBlocker.busy
            onToggled: AdBlocker.setEnabled(checked)
        }

        NavRow {
            icon: "shield"
            text: Tr.tr("Ad blocker & DNS")
            subtext: {
                if (!AdBlocker.loaded)
                    return Tr.tr("Checking AdGuard Home status…");
                if (!AdBlocker.installed || !AdBlocker.configured)
                    return Tr.tr("Set up AdGuard-powered system-wide blocking");
                if (AdBlocker.active)
                    return Tr.tr("%1 rules · Query log, filters & encrypted DNS").arg(AdBlocker.formatCompactCount(AdBlocker.totalEnabledRules));
                if (AdBlocker.paused)
                    return Tr.tr("Paused (%1 left) · Filters, query log & DNS").arg(AdBlocker.formatPauseCountdown(AdBlocker.pauseRemainingSec));
                return Tr.tr("Query log, filter lists, custom rules & encrypted DNS");
            }
            onClicked: root.nState.openSubPage(7) // Ad blocker sub-page
        }
    }
}
